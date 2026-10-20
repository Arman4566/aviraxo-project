// AI features with a fake Gemini (no network): prompt contents, permission-aware data, safe fallbacks, bill parsing.
const test = require('node:test');
const assert = require('node:assert/strict');
const { PsqlSession } = require('./helpers/psqlClient');
const config = require('../src/config');
const gemini = require('../src/services/gemini');
const ai = require('../src/services/ai');
const { todayIST } = require('../src/utils/time');

const fakeFetch = (text, seen = []) => async (url, opts) => {
  seen.push({ url, opts, body: JSON.parse(opts.body) });
  return { ok: true, status: 200, json: async () => ({ candidates: [{ content: { parts: [{ text }] } }] }) };
};

test('gemini client: needs a key, sends it in a header, maps errors', async () => {
  const old = config.geminiApiKey;
  config.geminiApiKey = '';
  await assert.rejects(gemini.generate({ contents: [] }), (e) => e.status === 503);
  config.geminiApiKey = 'k';
  const seen = [];
  assert.equal(await gemini.generate({ contents: [{ role: 'user', parts: [{ text: 'hi' }] }], json: true, fetchImpl: fakeFetch(' ok ', seen) }), 'ok');
  assert.equal(seen[0].opts.headers['x-goog-api-key'], 'k');
  assert.ok(!seen[0].url.includes('k?') && !seen[0].url.includes('key='), 'key never goes in the URL');
  assert.equal(seen[0].body.generationConfig.responseMimeType, 'application/json');
  await assert.rejects(gemini.generate({ contents: [], fetchImpl: async () => ({ ok: false, status: 429 }) }), (e) => e.status === 429);
  await assert.rejects(gemini.generate({ contents: [], fetchImpl: async () => ({ ok: false, status: 500 }) }), (e) => e.status === 502);
  await assert.rejects(gemini.generate({ contents: [], fetchImpl: async () => { throw new Error('net'); } }), (e) => e.status === 504);
  assert.deepEqual(gemini.parseJson('```json\n{"a":1}\n```'), { a: 1 });
  assert.throws(() => gemini.parseJson('nope'), (e) => e.status === 502);
  config.geminiApiKey = old;
});

test('scanBill cleans the model output (paise, valid GST slab, junk rows dropped)', async () => {
  config.geminiApiKey = 'k';
  const out = await ai.scanBill({ imageBase64: 'AAAA', mimeType: 'image/jpeg', fetchImpl: fakeFetch(JSON.stringify({
    supplier: 'Mehta Traders', bill_no: 'B-12', date: '2026-10-10',
    items: [{ name: ' Pen ', qty: 10, unit: 'pcs', rate: 12.5, gst_percent: 18, hsn: '9608-10' }, { name: '', qty: 1, rate: 5 }, { name: 'Odd', qty: 0, rate: 'x', gst_percent: 7 }],
  })) });
  assert.equal(out.items.length, 2);
  assert.deepEqual(out.items[0], { name: 'Pen', qty: 10, unit: 'pcs', rate: 1250, gst_percent: 18, hsn: '960810' });
  assert.equal(out.items[1].gst_percent, 0); assert.equal(out.items[1].qty, 1); assert.equal(out.items[1].rate, 0);
  assert.equal(out.date, '2026-10-10');
});

const DB = process.env.TEST_DB;
test('ask / summary / reminder draft on PostgreSQL', { skip: DB ? false : 'set TEST_DB to run' }, async (t) => {
  config.geminiApiKey = 'k';
  const s = new PsqlSession(DB);
  t.after(() => s.close());
  const q = (text, params) => s.query(text, params);
  await s.run('TRUNCATE users, businesses, parties, items, invoices, payments, expenses, audit_logs, reminder_rules, reminder_log, payment_promises RESTART IDENTITY CASCADE');
  const { rows: [u] } = await q(`INSERT INTO users (firebase_uid, email) VALUES ('ai1','a@b.c') RETURNING id`);
  const { rows: [b] } = await q(`INSERT INTO businesses (owner_user_id, name, state_code) VALUES ($1,'Sharma Stores','27') RETURNING *`, [u.id]);
  const { rows: [p] } = await q(`INSERT INTO parties (business_id, name, phone, type) VALUES ($1,'Asha Traders','9876543210','customer') RETURNING id`, [b.id]);
  const today = todayIST();
  await q(`INSERT INTO invoices (business_id, doc_type, affects_books, invoice_no, invoice_date, due_date, party_id, party_name, subtotal, taxable_value, grand_total, amount_paid, status)
           VALUES ($1,'gstInvoice',true,'INV-1',$2::date - 10,$2::date - 5,$3,'Asha Traders',150000,150000,150000,0,'unpaid')`, [b.id, today, p.id]);
  const db = { query: q };

  const seen = [];
  const owner = await ai.ask(db, { business: b, role: 'owner', question: 'Who owes me money?', history: [{ role: 'assistant', text: 'earlier' }], fetchImpl: fakeFetch('Asha owes 1500', seen) });
  assert.equal(owner.answer, 'Asha owes 1500');
  const ctx = seen[0].body.contents[0].parts[0].text;
  assert.ok(ctx.includes('Asha Traders') && ctx.includes('"owes":1500'), 'amounts are in rupees');
  assert.ok(ctx.includes('net_profit'), 'owner sees profit');
  assert.ok(seen[0].body.systemInstruction.parts[0].text.includes('untrusted'), 'prompt-injection guard present');
  assert.equal(seen[0].body.contents.at(-1).parts[0].text, 'Who owes me money?');

  const seenV = [];
  await ai.ask(db, { business: b, role: 'viewer', question: 'profit?', fetchImpl: fakeFetch('x', seenV) });
  assert.ok(!seenV[0].body.contents[0].parts[0].text.includes('net_profit'), 'viewer never receives profit/cost numbers');

  const sum = await ai.weeklySummary(db, { business: b, role: 'owner', fetchImpl: fakeFetch(JSON.stringify({ headline: 'Collect dues', points: [{ kind: 'warn', text: '₹1,500 is overdue', action: 'Send reminder' }, { kind: 'weird', text: '' }] })) });
  assert.equal(sum.points.length, 1); assert.equal(sum.points[0].kind, 'warn');

  const good = await ai.draftReminder(db, { business: b, partyId: p.id, language: 'en', fetchImpl: fakeFetch('Hi Asha, a gentle reminder: ₹1,500 is pending with Sharma Stores. Thanks!') });
  assert.equal(good.ai, true); assert.ok(good.message.startsWith('Hi Asha')); assert.equal(good.total_due, 150000);
  assert.ok(good.whatsapp_url, 'links are rebuilt around the AI wording');
  const bad = await ai.draftReminder(db, { business: b, partyId: p.id, language: 'en', fetchImpl: fakeFetch('Hi Asha, please pay soon!') });
  assert.equal(bad.ai, false, 'a rewrite that lost the amount is rejected');
  assert.ok(bad.message.includes('1,500'));
  const down = await ai.draftReminder(db, { business: b, partyId: p.id, language: 'en', fetchImpl: async () => { throw new Error('x'); } });
  assert.equal(down.ai, false, 'AI failure falls back to the plain template');
});
