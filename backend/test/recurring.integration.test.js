// Recurring invoices on a real PostgreSQL database (see services.integration.test.js for setup).
const test = require('node:test');
const assert = require('node:assert/strict');
const { PsqlSession, withTransaction } = require('./helpers/psqlClient');
const rec = require('../src/services/recurring');
const { todayIST } = require('../src/utils/time');

const DB = process.env.TEST_DB;
const skip = DB ? false : 'set TEST_DB to run';

test('nextRunDate keeps the day of month and clamps short months', () => {
  assert.equal(rec.nextRunDate('2026-01-31', 'monthly', 31), '2026-02-28');
  assert.equal(rec.nextRunDate('2026-02-28', 'monthly', 31), '2026-03-31');
  assert.equal(rec.nextRunDate('2026-11-30', 'quarterly', 30), '2027-02-28');
  assert.equal(rec.nextRunDate('2026-12-15', 'monthly', 15), '2027-01-15');
  assert.equal(rec.nextRunDate('2026-03-01', 'weekly', 1), '2026-03-08');
  assert.equal(rec.nextRunDate('2024-02-29', 'yearly', 29), '2025-02-28');
});

test('Recurring invoices on PostgreSQL', { skip }, async (t) => {
  const s = new PsqlSession(DB);
  t.after(() => s.close());
  const q = (text, params) => s.query(text, params);
  const db = { query: q, tx: (fn) => withTransaction(s, fn) };
  const TODAY = todayIST();
  const d = (n) => { const x = new Date(TODAY + 'T00:00:00Z'); x.setUTCDate(x.getUTCDate() + n); return x.toISOString().slice(0, 10); };

  await s.run('TRUNCATE users, businesses, parties, items, invoices, payments, audit_logs, recurring_invoices RESTART IDENTITY CASCADE');
  const { rows: [u] } = await q(`INSERT INTO users (firebase_uid, email) VALUES ('rc1','a@b.c') RETURNING id`);
  const { rows: [b] } = await q(`INSERT INTO businesses (owner_user_id, name, state_code) VALUES ($1,'Rent Co','27') RETURNING *`, [u.id]);
  const { rows: [p] } = await q(`INSERT INTO parties (business_id, name, phone, type) VALUES ($1,'Tenant One','9000000000','customer') RETURNING id`, [b.id]);
  const line = { name: 'Monthly rent', unit: 'pcs', hsn: '', gst_slab: 0, qty: 1, rate: 1500000, discount_is_percent: true, discount_value: 0, tax_inclusive: false };
  const input = (over = {}) => ({ name: 'Rent', party_id: Number(p.id), frequency: 'weekly', start_date: d(-14), doc_type: 'gstInvoice', payment_method: 'Credit (Pay Later)', due_days: 5, gst_enabled: false, notes: '', terms: '', lines: [line], ...over });

  await assert.rejects(rec.create(db, { biz: b, userId: u.id, input: input({ party_id: 999 }) }), /Party not found/);
  const id = await rec.create(db, { biz: b, userId: u.id, input: input() });

  // 14 days ago, 7 days ago and today are all due: three invoices, then the schedule sits one week ahead.
  const r1 = await rec.runDue(db, { biz: b, userId: u.id, today: TODAY });
  assert.equal(r1.created.length, 3);
  assert.deepEqual(r1.created.map((c) => c.date), [d(-14), d(-7), d(0)]);
  const sched = (await rec.list(db, b.id))[0];
  assert.equal(sched.next_date, d(7));
  assert.equal(sched.run_count, 3);
  const { rows: inv } = await q(`SELECT invoice_date::text AS dt, due_date::text AS due, grand_total, status FROM invoices WHERE business_id = $1 ORDER BY invoice_date`, [b.id]);
  assert.equal(inv.length, 3);
  assert.equal(inv[0].due, d(-9));
  assert.equal(Number(inv[0].grand_total), 1500000);

  // Running again the same day creates nothing (no double billing).
  const r2 = await rec.runDue(db, { biz: b, userId: u.id, today: TODAY });
  assert.equal(r2.created.length, 0);
  assert.equal((await q(`SELECT count(*) AS n FROM invoices WHERE business_id = $1`, [b.id])).rows[0].n, 3);

  // Paused schedules do not run; resumed ones do.
  await rec.setActive(db, b.id, id, false);
  assert.equal((await rec.runDue(db, { biz: b, userId: u.id, today: d(30) })).created.length, 0);
  await rec.setActive(db, b.id, id, true);
  assert.equal((await rec.runDue(db, { biz: b, userId: u.id, today: d(30) })).created.length, 4);

  // A schedule with an end date stops itself after the last run.
  const id2 = await rec.create(db, { biz: b, userId: u.id, input: input({ name: 'Short', start_date: d(0), end_date: d(8) }) });
  const r3 = await rec.runDue(db, { biz: b, userId: u.id, today: d(40) });
  assert.equal(r3.created.filter((c) => c.recurring_id === Number(id2)).length, 2);
  assert.equal((await rec.list(db, b.id)).find((x) => x.id === Number(id2)).is_active, false);

  // A locked period is skipped, not back-dated.
  const id3 = await rec.create(db, { biz: { ...b, settings: { booksLockedUntil: d(-1) } }, userId: u.id, input: input({ name: 'Locked', start_date: d(-3), frequency: 'monthly' }) });
  const r4 = await rec.runDue(db, { biz: { ...b, settings: { booksLockedUntil: d(-1) } }, userId: u.id, today: TODAY });
  assert.equal(r4.created.filter((c) => c.recurring_id === Number(id3)).length, 0);
  assert.notEqual((await rec.list(db, b.id)).find((x) => x.id === Number(id3)).next_date, d(-3));

  // Other businesses cannot touch the schedule.
  const { rows: [u2] } = await q(`INSERT INTO users (firebase_uid, email) VALUES ('rc2','x@y.z') RETURNING id`);
  const { rows: [b2] } = await q(`INSERT INTO businesses (owner_user_id, name, state_code) VALUES ($1,'Other','27') RETURNING *`, [u2.id]);
  await assert.rejects(rec.remove(db, b2.id, id), /not found/);
  assert.equal((await rec.list(db, b2.id)).length, 0);
  await rec.remove(db, b.id, id);
});
