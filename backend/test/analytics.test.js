// Analytics overview against real PostgreSQL (runs when TEST_DB is set) plus the pure helpers.
const test = require('node:test');
const assert = require('node:assert/strict');
const { PsqlSession } = require('./helpers/psqlClient');
const an = require('../src/services/analytics');

test('granularity keeps charts readable', () => {
  assert.equal(an.granularityFor(7), 'day');
  assert.equal(an.granularityFor(45), 'day');
  assert.equal(an.granularityFor(90), 'week');
  assert.equal(an.granularityFor(365), 'month');
});

const DB = process.env.TEST_DB;
test('overview totals, comparison, series and rankings', { skip: DB ? false : 'set TEST_DB to run' }, async (t) => {
  const s = new PsqlSession(DB);
  t.after(() => s.close());
  const q = (text, params) => s.query(text, params);
  await s.run('TRUNCATE users, businesses, parties, items, invoices, payments, expenses, audit_logs RESTART IDENTITY CASCADE');
  const { rows: [u] } = await q(`INSERT INTO users (firebase_uid, email) VALUES ('an1','a@b.c') RETURNING id`);
  const { rows: [b] } = await q(`INSERT INTO businesses (owner_user_id, name) VALUES ($1,'Shop') RETURNING id`, [u.id]);
  const { rows: [it] } = await q(`INSERT INTO items (business_id, name, purchase_price) VALUES ($1,'Pen',6000) RETURNING id`, [b.id]);
  const inv = async (no, date, total, status = 'paid', name = 'Asha', type = 'retailInvoice', books = true) => {
    const { rows: [i] } = await q(
      `INSERT INTO invoices (business_id, doc_type, affects_books, invoice_no, invoice_date, party_name, subtotal, taxable_value, grand_total, amount_paid, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$7,$7,0,$8) RETURNING id`, [b.id, type, books, no, date, name, total, status]);
    await q(`INSERT INTO invoice_lines (invoice_id, item_id, name, qty, rate, line_base, taxable_value, line_total) VALUES ($1,$2,'Pen',$3,$4,$5,$5,$5)`,
      [i.id, it.id, 2, total / 2, total]);
    return i.id;
  };
  // current window 2026-10-05..2026-10-18 (14 days); previous 2026-09-21..2026-10-04
  await inv('A1', '2026-10-10', 20000);
  await inv('A2', '2026-10-12', 10000, 'unpaid', 'Ravi');
  await inv('A3', '2026-10-13', 99999, 'cancelled');             // ignored
  await inv('A4', '2026-10-14', 99999, 'open', 'Quote', 'estimate', false); // ignored: not a sale
  await inv('P1', '2026-09-25', 15000);
  await q(`INSERT INTO payments (business_id, direction, payment_date, amount, mode) VALUES ($1,'in','2026-10-10',20000,'upi'),($1,'in','2026-10-11',5000,'cash')`, [b.id]);
  await q(`INSERT INTO expenses (business_id, kind, category, amount, entry_date) VALUES ($1,'expense','Rent',8000,'2026-10-06'),($1,'income','Interest',1000,'2026-10-07')`, [b.id]);

  const o = await an.overview({ query: q }, b.id, { from: '2026-10-05', to: '2026-10-18' });
  assert.equal(o.days, 14); assert.equal(o.granularity, 'day');
  assert.equal(o.totals.sales, 30000); assert.equal(o.totals.orders, 2); assert.equal(o.totals.avg_order, 15000);
  assert.equal(o.totals.collected, 25000); assert.equal(o.totals.expenses, 8000); assert.equal(o.totals.other_income, 1000);
  // cost: 2 invoices x qty 2 x 6000 = 24000, revenue 30000 -> gross 6000; net = 6000 + 1000 - 8000
  assert.equal(o.totals.gross_profit, 6000); assert.equal(o.totals.net_profit, -1000);
  assert.equal(o.previous_totals.sales, 15000); assert.equal(o.change_pct.sales, 100);
  assert.equal(o.series.length, 14); assert.equal(o.series[0].date, '2026-10-05');
  assert.equal(o.series.find((p) => p.date === '2026-10-10').sales, 20000);
  assert.equal(o.series.find((p) => p.date === '2026-10-06').expenses, 8000);
  assert.equal(o.series.reduce((x, p) => x + p.sales, 0), 30000, 'series adds up to the total');
  assert.deepEqual(o.top_customers.map((c) => c.name), ['Asha', 'Ravi']);
  assert.equal(o.top_items[0].name, 'Pen'); assert.equal(o.top_items[0].revenue, 30000);
  assert.deepEqual(o.payment_modes.map((m) => m.mode), ['upi', 'cash']); assert.equal(o.payment_modes[0].share_pct, 80);
  assert.deepEqual(o.expense_categories, [{ category: 'Rent', total: 8000 }]);
  assert.equal(o.monthly.length, 6); assert.equal(o.monthly[5].month, '2026-10'); assert.equal(o.monthly[5].sales, 30000);
  assert.equal(o.monthly[4].month, '2026-09'); assert.equal(o.monthly[4].sales, 15000);
  assert.equal(o.best_weekday, 6, '2026-10-10 is a Saturday');

  const wide = await an.overview({ query: q }, b.id, { from: '2026-04-01', to: '2026-10-18' });
  assert.equal(wide.granularity, 'month');
  assert.equal(wide.series.reduce((x, p) => x + p.sales, 0), 45000);
});
