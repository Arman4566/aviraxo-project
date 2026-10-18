// Calls the Phase 2-6 route handlers against PostgreSQL with stubbed express/zod/pg (they cannot be installed offline).
// Proves the wiring (names, arguments, SQL, JSON shape) end to end; request validation is covered by zod in production.
//   TEST_DB=aviraxo_it npm test
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const Module = require('node:module');
const { PsqlSession, withTransaction } = require('./helpers/psqlClient');
const DB = process.env.TEST_DB;

test('Phase 2-6 route handlers run against PostgreSQL', { skip: DB ? false : 'set TEST_DB' }, async (t) => {
  const s = new PsqlSession(DB);
  t.after(() => s.close());
  const src = (p) => path.resolve(__dirname, '../src', p);
  const stub = (id, exp) => { require.cache[id] = { id, filename: id, loaded: true, exports: exp }; };
  const handlers = {};
  let cur = null;
  const router = new Proxy({}, { get: (_, verb) => (route, ...fns) => { handlers[`${verb} ${cur}${route}`] = fns[fns.length - 1]; } });
  const chain = () => new Proxy(function () {}, { get: () => chain(), apply: () => chain() });
  const orig = Module._resolveFilename;
  Module._resolveFilename = function (r, ...a) {
    if (r === 'express') return 'express-stub';
    if (r === 'zod') return 'zod-stub';
    return orig.call(this, r, ...a);
  };
  stub('express-stub', { Router: () => router });
  stub('zod-stub', { z: chain() });
  stub(src('db.js'), { query: (text, p) => s.query(text, p), withTransaction: (fn) => withTransaction(s, fn) });
  const load = (name) => { cur = name; delete require.cache[src(`routes/${name}.js`)]; require(src(`routes/${name}.js`)); };
  ['receivables', 'reminders', 'promises', 'expenses', 'inventory', 'staff', 'insights', 'reports', 'backup', 'invoices'].forEach(load);
  Module._resolveFilename = orig;

  await s.run('TRUNCATE users, businesses, parties, items, invoices, payments, expenses, staff_invites, audit_logs, reminder_rules, reminder_log, payment_promises RESTART IDENTITY CASCADE');
  const { rows: [u] } = await s.query(`INSERT INTO users (firebase_uid, email) VALUES ('s1','o@s.in') RETURNING id`);
  const { rows: [biz] } = await s.query(`INSERT INTO businesses (owner_user_id, name, gst_registered, gstin, state_code, settings) VALUES ($1,'Smoke Shop',true,'27AAPFU0939F1ZV','27','{"upiId":"smoke@okhdfc"}') RETURNING *`, [u.id]);
  await s.query(`INSERT INTO business_users (business_id, user_id, role) VALUES ($1,$2,'owner')`, [biz.id, u.id]);
  const { rows: [p] } = await s.query(`INSERT INTO parties (business_id, name, phone) VALUES ($1,'Asha','9876543210') RETURNING id`, [biz.id]);
  await s.query(`INSERT INTO invoices (business_id, doc_type, affects_books, invoice_no, invoice_date, due_date, party_id, subtotal, taxable_value, grand_total, status)
                 VALUES ($1,'gstInvoice',true,'INV-00001','2026-10-01','2026-10-05',$2,100000,100000,100000,'unpaid')`, [biz.id, p.id]);
  await s.query(`INSERT INTO items (business_id, name, selling_price, low_stock_level, barcode) VALUES ($1,'Cable',100,5,'123456789')`, [biz.id]);

  const call = async (key, req = {}) => {
    let out, status = 200, ended = false;
    const res = { json: (v) => { out = v; return res; }, status: (c) => { status = c; return res; }, end: () => { ended = true; }, setHeader() {} };
    const fn = handlers[key] || handlers[`${key}/`];
    assert.ok(fn, `handler ${key} is registered`);
    await fn({ business: { ...biz, role: 'owner' }, user: { id: u.id }, query: {}, params: {}, body: {}, headers: {}, ...req }, res, (e) => { if (e) throw e; });
    return { out, status, ended };
  };

  const sum = (await call('get receivables/summary')).out;
  assert.equal(sum.total_receivable, 100000);
  assert.equal((await call('get receivables/aging')).out.buckets.d1_30 >= 0, true);
  assert.equal((await call('get receivables/parties', { query: { sort: 'overdue' } })).out.parties.length, 1);
  assert.equal((await call('put receivables/parties/:id/reminders', { params: { id: String(p.id) }, body: { paused: true } })).out.reminders_paused, true);
  await call('put receivables/parties/:id/reminders', { params: { id: String(p.id) }, body: { paused: false } });

  const rules = (await call('get reminders/rules')).out.rules;
  assert.equal(rules.length, 3);
  const compose = (await call('post reminders/compose', { body: { party_id: p.id, language: 'en', template: '' } })).out;
  assert.match(compose.whatsapp_url, /wa\.me\/919876543210/); assert.match(compose.message, /smoke@okhdfc/);
  assert.equal((await call('get reminders/due')).out.count >= 0, true);
  const logged = (await call('post reminders/log', { body: { party_id: p.id, channel: 'whatsapp', status: 'sent', message: compose.message, total_due: 100000, items: [] } })).out;
  assert.equal(logged.logged, 1);
  assert.equal((await call('get reminders/log', { query: { party_id: p.id, limit: 10 } })).out.log.length, 1);
  const created = await call('post reminders/rules', { body: { name: 'Hindi final', trigger_type: 'after_due', offset_days: 30, tone: 'final', language: 'hi', channel: 'whatsapp', template: '', is_active: true } });
  assert.equal(created.status, 201);
  await call('put reminders/rules/:id', { params: { id: String(created.out.rule.id) }, body: { is_active: false } });
  assert.equal((await call('delete reminders/rules/:id', { params: { id: String(created.out.rule.id) } })).ended, true);

  const pr = (await call('post promises', { body: { party_id: p.id, promised_date: '2099-01-01', amount: 0, note: 'x' } })).out.promise;
  assert.equal(pr.status, 'open');
  assert.equal((await call('get promises', { query: {} })).out.promises.length, 1);
  assert.equal((await call('put promises/:id', { params: { id: String(pr.id) }, body: { status: 'cancelled' } })).out.promise.status, 'cancelled');

  const ex = (await call('post expenses', { body: { kind: 'expense', category: 'Tea', amount: 5000, gst_amount: 0, mode: 'cash', entry_date: '2026-10-10', note: '', receipt_url: '' } })).out.expense;
  assert.equal((await call('get expenses', { query: {} })).out.expenses.length, 1);
  assert.equal((await call('get expenses/summary', { query: { from: '2026-10-01', to: '2026-10-31' } })).out.total_expense, 5000);
  assert.ok((await call('get expenses/categories')).out.categories.includes('Tea'));
  await call('put expenses/:id', { params: { id: String(ex.id) }, body: { amount: 6000 } });
  assert.equal((await call('delete expenses/:id', { params: { id: String(ex.id) } })).ended, true);

  assert.equal((await call('get inventory/low-stock')).out.low >= 0, true);
  assert.equal((await call('get inventory/barcode/:code', { params: { code: '123456789' } })).out.item.name, 'Cable');
  await assert.rejects(call('get inventory/barcode/:code', { params: { code: 'nope' } }), /No item/);

  const range = { from: '2026-10-01', to: '2026-10-31' };
  for (const k of ['profit-loss', 'cash-flow', 'gstr1', 'gstr3b']) assert.ok((await call(`get reports/${k}`, { query: range })).out, k);
  assert.ok((await call('get reports/day-book', { query: { date: '2026-10-05' } })).out.entries);
  assert.ok((await call('get reports/cash-bank')).out.accounts);
  await assert.rejects(call('get reports/gstr1', { query: range, business: { ...biz, role: 'cashier' } }), /only available/);

  assert.ok((await call('get insights/summary')).out.insights);
  assert.equal((await call('get insights/forecast', { query: { days: 28 } })).out.buckets.length, 4);
  assert.equal((await call('get insights/risk/:partyId', { params: { partyId: String(p.id) } })).out.party_id, p.id);
  assert.equal((await call('get insights/gstin/:gstin', { params: { gstin: '27AAPFU0939F1ZV' } })).out.valid, true);
  assert.equal((await call('post insights/check-invoice', { body: { party_id: p.id, total: 1, gst_enabled: false, lines: [] } })).out.ok, true);

  const list = (await call('get staff')).out;
  assert.equal(list.members.length, 1);
  const inv = (await call('post staff/invite', { body: { email: 'new@s.in', role: 'cashier' } })).out.invite;
  assert.equal((await call('delete staff/invites/:id', { params: { id: String(inv.id) } })).ended, true);
  assert.ok((await call('get staff/audit/log', { query: { limit: 10 } })).out.log.length >= 1);

  const bk = (await call('get backup/export')).out;
  assert.equal(bk.counts.parties, 1);
  await assert.rejects(call('post backup/restore', { business: { ...biz, role: 'manager' }, body: bk }), /Only the owner/);
  const { rows: [empty] } = await s.query(`INSERT INTO businesses (owner_user_id, name, state_code) VALUES ($1,'New firm','27') RETURNING *`, [u.id]);
  const rs = (await call('post backup/restore', { business: { ...empty, role: 'owner' }, body: JSON.parse(JSON.stringify(bk)) })).out;
  assert.equal(rs.restored.invoices, 1);

  assert.ok(handlers['post invoices/:id/convert'] && handlers['post invoices/:id/cancel'], 'convert and cancel routes are registered');
});
