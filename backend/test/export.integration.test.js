// Every report export runs its real SQL on PostgreSQL, on invoices created through the real invoice code path.
const test = require('node:test');
const assert = require('node:assert/strict');
const { PsqlSession, withTransaction } = require('./helpers/psqlClient');
const rec = require('../src/services/recurring');
const ex = require('../src/services/exporter');
const { itemJson, ITEM_SELECT } = require('../src/services/itemQueries');
const { todayIST } = require('../src/utils/time');

const DB = process.env.TEST_DB;
test('report exports on PostgreSQL', { skip: DB ? false : 'set TEST_DB to run' }, async (t) => {
  const s = new PsqlSession(DB);
  t.after(() => s.close());
  const q = (text, params) => s.query(text, params);
  const db = { query: q, tx: (fn) => withTransaction(s, fn) };
  const TODAY = todayIST();
  await s.run('TRUNCATE users, businesses, parties, items, invoices, payments, expenses, audit_logs, recurring_invoices RESTART IDENTITY CASCADE');
  const { rows: [u] } = await q(`INSERT INTO users (firebase_uid, email) VALUES ('ex1','a@b.c') RETURNING id`);
  const { rows: [b] } = await q(`INSERT INTO businesses (owner_user_id, name, state_code, gst_registered) VALUES ($1,'Export Co','27',true) RETURNING *`, [u.id]);
  const { rows: [p] } = await q(`INSERT INTO parties (business_id, name, phone, type) VALUES ($1,'Asha Traders','9876543210','customer') RETURNING id`, [b.id]);
  await q(`INSERT INTO items (business_id, name, unit, purchase_price, selling_price, stock_enabled, packaging) VALUES ($1,'Soap','pcs',1000,1500,true,$2::jsonb)`,
    [b.id, JSON.stringify([{ tier: 'primary', name: 'Case', enabled: true, per: 12 }])]);
  await q(`INSERT INTO expenses (business_id, expense_date, category, amount, created_by) VALUES ($1,$2,'Rent',50000,$3)`, [b.id, TODAY, u.id]).catch(() => {});

  const line = { name: 'Soap', unit: 'pcs', hsn: '3401', gst_slab: 18, qty: 10, rate: 10000, discount_is_percent: true, discount_value: 0, tax_inclusive: false };
  await rec.create(db, { biz: b, userId: u.id, input: { name: 'Soap sale', party_id: Number(p.id), frequency: 'weekly', start_date: TODAY, doc_type: 'gstInvoice', payment_method: 'Credit (Pay Later)', due_days: 5, gst_enabled: true, notes: '', terms: '', lines: [line] } });
  await rec.runDue(db, { biz: b, userId: u.id, today: TODAY });

  const range = { from: `${TODAY.slice(0, 8)}01`, to: TODAY };
  const pl = await ex.table(db, b, 'profit-loss', range);
  assert.equal(pl.rows.find((r) => r[0] === 'Sales (before tax)')[1], 1000);   // 10 x Rs 100
  const sales = await ex.table(db, b, 'sales', range);
  assert.equal(sales.rows[0][1], 1); assert.equal(sales.rows[0][2], 1180);
  for (const group of ['party', 'item']) {
    const g = await ex.table(db, b, 'sales', { ...range, group });
    assert.equal(g.rows.length, 1);
    assert.equal(g.rows[0][2], 1180);
  }
  const tax = await ex.table(db, b, 'tax-summary', range);
  const tot = tax.rows[tax.rows.length - 1];
  assert.deepEqual([tax.rows[0][0], tot[0], tot[1], tot[5]], ['18%', 'Total', 1000, 180]);
  const rcv = await ex.table(db, b, 'receivables', {});
  assert.deepEqual(rcv.rows, [['Asha Traders', 1180]]);
  const stock = await ex.table(db, b, 'stock', {});
  assert.equal(stock.rows[0][0], 'Soap');

  // formats
  for (const r of ex.REPORTS) {
    const tb = await ex.table(db, b, r, range);
    assert.ok(ex.render(tb, 'csv').body.length > 5);
    assert.ok(ex.render(tb, 'xlsx').body.length > 200);
  }
  // packaging survives the real column round trip
  const { rows } = await q(`${ITEM_SELECT} WHERE i.business_id = $1`, [b.id]);
  const pk = itemJson(rows[0]).packaging;
  assert.equal(pk.find((x) => x.tier === 'primary').pieces, 12);
});
