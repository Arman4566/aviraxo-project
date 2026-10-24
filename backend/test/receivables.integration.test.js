// Payment tracking + reminders against a real PostgreSQL database (see services.integration.test.js for setup).
const test = require('node:test');
const assert = require('node:assert/strict');
const { PsqlSession, withTransaction } = require('./helpers/psqlClient');
const { createInvoice } = require('../src/services/invoices');
const { recordPayment } = require('../src/services/payments');
const rec = require('../src/services/receivables');
const rem = require('../src/services/reminders');

const DB = process.env.TEST_DB;
const skip = DB ? false : 'set TEST_DB to run';
const { todayIST } = require('../src/utils/time');
const TODAY = todayIST();
const d = (n) => { const x = new Date(TODAY + 'T00:00:00Z'); x.setUTCDate(x.getUTCDate() + n); return x.toISOString().slice(0, 10); };
const line = (rate) => ({ name: 'Goods', unit: 'pcs', hsn: '', gst_slab: 0, qty: 1, rate, discount_is_percent: true, discount_value: 0, tax_inclusive: false });

test('Payment tracking and reminders on PostgreSQL', { skip }, async (t) => {
  const s = new PsqlSession(DB);
  t.after(() => s.close());
  const q = (text, params) => s.query(text, params);
  const tx = (fn) => withTransaction(s, fn);

  await s.run('TRUNCATE users, businesses, parties, items, invoices, payments, audit_logs, reminder_rules, reminder_log, payment_promises RESTART IDENTITY CASCADE');
  const { rows: [u] } = await q(`INSERT INTO users (firebase_uid, email) VALUES ('r1','a@b.c') RETURNING id`);
  const { rows: [b] } = await q(
    `INSERT INTO businesses (owner_user_id, name, state_code, settings) VALUES ($1,'Ramesh Electronics','27','{"upiId":"ramesh@okhdfc"}') RETURNING *`, [u.id]);
  const { rows: [u2] } = await q(`INSERT INTO users (firebase_uid, email) VALUES ('r2','x@y.z') RETURNING id`);
  const { rows: [b2] } = await q(`INSERT INTO businesses (owner_user_id, name, state_code) VALUES ($1,'Other Shop','27') RETURNING *`, [u2.id]);
  const mkParty = async (name, phone, extra = '', biz = b) =>
    (await q(`INSERT INTO parties (business_id, name, phone, ${extra ? 'reminders_paused,' : ''} type) VALUES ($1,$2,$3,${extra ? 'true,' : ''}'customer') RETURNING id`, [biz.id, name, phone])).rows[0].id;
  const credit = (party, rate, due, date = d(-47), biz = b) =>
    tx((c) => createInvoice(c, { biz, userId: u.id, body: { doc_type: 'gstInvoice', party_id: party, payment_method: 'Credit (Pay Later)', invoice_date: date, due_date: due, gst_enabled: false, notes: '', terms: '', cash_customer: false, lines: [line(rate)] } }));

  const asha = await mkParty('Asha Traders', '98765 43210');     // due today
  const bharat = await mkParty('Bharat Stores', '');              // 3 days overdue, no phone
  const chitra = await mkParty('Chitra Mart', '9123456789', 'paused'); // overdue but reminders paused
  const dev = await mkParty('Dev Agency', '9000000001');          // due in 2 days
  const esha = await mkParty('Esha Boutique', '9000000002');      // 40 days overdue
  const other = await mkParty('Other tenant customer', '9000000003', '', b2);
  await credit(asha, 100000, TODAY);
  await credit(bharat, 250000, d(-3));
  await credit(chitra, 80000, d(-17));
  await credit(dev, 60000, d(2));
  await credit(esha, 500000, d(-40));
  await credit(other, 999900, d(-17), d(-47), b2);

  await t.test('default rules are created once, per business', async () => {
    await tx((c) => rem.ensureDefaultRules(c, b.id));
    await tx((c) => rem.ensureDefaultRules(c, b.id));
    assert.equal((await rem.listRules(s, b.id)).length, 3);
    assert.equal((await rem.listRules(s, b2.id)).length, 0);
  });

  await t.test('summary and aging add up, and other businesses never leak in', async () => {
    const sum = await rec.summary(s, b.id);
    assert.equal(sum.total_receivable, 100000 + 250000 + 80000 + 60000 + 500000);
    assert.equal(sum.overdue, 250000 + 80000 + 500000);
    assert.equal(sum.due_today, 100000);
    assert.equal(sum.due_next_7_days, 60000);
    assert.equal(sum.overdue_parties, 3);
    const mo = await rec.monthly(s, b.id);
    assert.equal(mo.to_collect, sum.total_receivable);
    assert.equal(mo.to_pay, 0);
    assert.match(mo.month, /^\d{4}-\d{2}$/);
    assert.equal((await rec.monthly(s, b2.id)).to_collect, (await rec.summary(s, b2.id)).total_receivable);
    const a = await rec.aging(s, b.id);
    assert.equal(a.buckets.not_due, 160000);        // Asha today + Dev in 2 days
    assert.equal(a.buckets.d1_30, 330000);          // Bharat 3d + Chitra 17d
    assert.equal(a.buckets.d31_60, 500000);         // Esha 40d
    assert.equal(a.buckets.d90_plus, 0);
    assert.equal(a.total, 990000);
    assert.ok(!a.parties.some((p) => p.name.startsWith('Other')));
  });

  await t.test('outstanding list ranks by overdue and flags credit/risk fields', async () => {
    const out = await rec.outstandingParties(s, b.id, { sort: 'overdue' });
    assert.deepEqual(out.parties.map((p) => p.name), ['Esha Boutique', 'Bharat Stores', 'Chitra Mart', 'Asha Traders', 'Dev Agency']);
    assert.equal(out.parties[0].oldest_days_overdue, 40);
    assert.equal(out.parties[0].risk_label, 'medium');       // only overdue, nothing paid yet: 20% share + 40d age
    const only = await rec.outstandingParties(s, b.id, { bucket: 'd31_60' });
    assert.deepEqual(only.parties.map((p) => p.name), ['Esha Boutique']);
  });

  await t.test('today: due-today, 3-days-overdue and 2-days-before reminders fire; paused and distant ones do not', async () => {
    const list = await tx((c) => rem.dueToday(c, { business: b, today: TODAY }));
    const names = list.map((r) => r.party_name).sort();
    // Esha is 40 days overdue: 3 + 7k = 37, 44 -> not today. Chitra is paused. Bharat: 3 days overdue -> fires.
    assert.deepEqual(names, ['Asha Traders', 'Bharat Stores', 'Dev Agency']);
    const bharat = list.find((r) => r.party_name === 'Bharat Stores');
    assert.equal(bharat.tone, 'firm');
    assert.equal(bharat.has_phone, false);
    assert.equal(bharat.whatsapp_url, null);
    assert.match(bharat.message, /₹2,500/);
    const asha = list.find((r) => r.party_name === 'Asha Traders');
    assert.equal(asha.tone, 'friendly');
    assert.match(asha.whatsapp_url, /^https:\/\/wa\.me\/919876543210\?text=/);
    assert.match(asha.message, /ramesh@okhdfc/);
    assert.match(asha.upi_url, /^upi:\/\/pay\?pa=ramesh%40okhdfc&pn=Ramesh%20Electronics&am=1000\.00/);
    assert.equal(asha.items.length, 1);
  });

  await t.test('sending is logged once; the same reminder does not come back that day', async () => {
    const list = await tx((c) => rem.dueToday(c, { business: b, today: TODAY }));
    const asha = list.find((r) => r.party_name === 'Asha Traders');
    const r1 = await tx((c) => rem.logReminder(c, { businessId: b.id, userId: u.id, partyId: asha.party_id, channel: 'whatsapp', message: asha.message, items: asha.items, totalDue: asha.total_due, today: TODAY }));
    const r2 = await tx((c) => rem.logReminder(c, { businessId: b.id, userId: u.id, partyId: asha.party_id, channel: 'whatsapp', message: asha.message, items: asha.items, totalDue: asha.total_due, today: TODAY }));
    assert.deepEqual([r1.logged, r2.logged], [1, 0]);
    const again = await tx((c) => rem.dueToday(c, { business: b, today: TODAY }));
    assert.ok(!again.some((r) => r.party_name === 'Asha Traders'));
    assert.equal((await rem.listLog(s, b.id, { partyId: asha.party_id })).length, 1);
    const out = await rec.outstandingParties(s, b.id);
    assert.equal(out.parties.find((p) => p.name === 'Asha Traders').last_reminder_on, TODAY);
  });

  await t.test('a promise to pay silences overdue nagging until its date, then is marked broken', async () => {
    const bharat = (await q(`SELECT id FROM parties WHERE name = 'Bharat Stores'`)).rows[0].id;
    await assert.rejects(tx((c) => rem.createPromise(c, { businessId: b.id, userId: u.id, partyId: bharat, promisedDate: d(-17), today: TODAY })), /past/);
    const p = await tx((c) => rem.createPromise(c, { businessId: b.id, userId: u.id, partyId: bharat, promisedDate: d(4), amount: 250000, note: 'after Diwali stock sale', today: TODAY }));
    assert.equal(p.status, 'open');
    const list = await tx((c) => rem.dueToday(c, { business: b, today: TODAY }));
    assert.ok(!list.some((r) => r.party_name === 'Bharat Stores'), 'no nagging while the promise is open');
    const out = await rec.outstandingParties(s, b.id);
    assert.equal(out.parties.find((x) => x.name === 'Bharat Stores').open_promise.promised_date, d(4));
    // a newer promise replaces the old open one
    await tx((c) => rem.createPromise(c, { businessId: b.id, userId: u.id, partyId: bharat, promisedDate: d(7), today: TODAY }));
    assert.equal((await rem.listPromises(s, b.id, { partyId: bharat, status: 'cancelled', today: TODAY })).length, 1);
    // date passes unpaid -> broken
    const later = await rem.listPromises(s, b.id, { partyId: bharat, today: d(8) });
    assert.deepEqual(later.map((x) => x.status).sort(), ['broken', 'cancelled']);
  });

  await t.test('paying in full marks the promise kept and clears the outstanding list', async () => {
    const dev = (await q(`SELECT id FROM parties WHERE name = 'Dev Agency'`)).rows[0].id;
    await tx((c) => rem.createPromise(c, { businessId: b.id, userId: u.id, partyId: dev, promisedDate: d(1), today: TODAY }));
    await tx((c) => recordPayment(c, { businessId: b.id, userId: u.id, partyId: dev, amount: 60000, mode: 'upi', paymentDate: TODAY }));
    const ps = await rem.listPromises(s, b.id, { partyId: dev, today: TODAY });
    assert.equal(ps[0].status, 'kept');
    const out = await rec.outstandingParties(s, b.id);
    assert.ok(!out.parties.some((p) => p.name === 'Dev Agency'));
    const sum = await rec.summary(s, b.id);
    assert.equal(sum.collected_this_month >= 60000, true);
  });

  await t.test('compose on demand picks the tone from how late it is, supports Hindi and custom text', async () => {
    const esha = (await q(`SELECT id FROM parties WHERE name = 'Esha Boutique'`)).rows[0].id;
    const m = await rem.compose(s, { business: b, partyId: esha, today: TODAY });
    assert.equal(m.tone, 'final');
    assert.equal(m.total_due, 500000);
    assert.match(m.message, /40 days overdue/);
    const hi = await rem.compose(s, { business: b, partyId: esha, language: 'hi', tone: 'friendly', today: TODAY });
    assert.match(hi.message, /नमस्ते/);
    const custom = await rem.compose(s, { business: b, partyId: esha, template: 'Please pay {amount}', today: TODAY });
    assert.equal(custom.message, 'Please pay ₹5,000');
    const asha = (await q(`SELECT id FROM parties WHERE name = 'Asha Traders'`)).rows[0].id;
    await tx((c) => recordPayment(c, { businessId: b.id, userId: u.id, partyId: asha, amount: 100000, mode: 'cash', paymentDate: TODAY }));
    await assert.rejects(rem.compose(s, { business: b, partyId: asha, today: TODAY }), /nothing pending/);
    const otherParty = (await q(`SELECT id FROM parties WHERE business_id = $1`, [b2.id])).rows[0].id;
    await assert.rejects(rem.compose(s, { business: b, partyId: otherParty, today: TODAY }), /Party not found/);
  });

  await t.test('risk uses payment history: Asha paid on the due date, so she scores low', async () => {
    const asha = (await q(`SELECT id FROM parties WHERE name = 'Asha Traders'`)).rows[0].id;
    await credit(asha, 70000, d(12), TODAY);
    const out = await rec.outstandingParties(s, b.id);
    const a = out.parties.find((p) => p.name === 'Asha Traders');
    assert.equal(a.risk_label, 'low');
  });

  await t.test('rule editing: validation and tenant isolation', async () => {
    const r = await tx((c) => rem.createRule(c, b.id, { name: 'Final notice', trigger_type: 'after_due', offset_days: 30, tone: 'final', language: 'hi' }));
    assert.equal(r.language, 'hi');
    await assert.rejects(tx((c) => rem.createRule(c, b.id, { name: 'bad', trigger_type: 'on_due', repeat_every_days: 3 })), /Only after-due/);
    const u1 = await tx((c) => rem.updateRule(c, b.id, r.id, { is_active: false }));
    assert.equal(u1.is_active, false);
    await assert.rejects(tx((c) => rem.updateRule(c, b2.id, r.id, { name: 'hijack' })), /not found/);
    await assert.rejects(tx((c) => rem.deleteRule(c, b2.id, r.id)), /not found/);
    await tx((c) => rem.deleteRule(c, b.id, r.id));
  });
});
