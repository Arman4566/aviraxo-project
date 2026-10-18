// Insights, forecast, health score and invoice sanity checks (pure parts always; database parts when TEST_DB is set).
const test = require('node:test');
const assert = require('node:assert/strict');
const { PsqlSession } = require('./helpers/psqlClient');
const ins = require('../src/services/insights');
const { isValidGstin } = require('../src/utils/invoiceMath');

test('insight cards are plain language and only appear when they matter', () => {
  const base = { sales_week: 0, sales_prev_week: 0, overdue_total: 0, receivable_total: 0, top_debtor: null, out_of_stock: 0, low_stock: 0, top_sellers: [], slow_value: 0, slow_count: 0 };
  assert.deepEqual(ins.buildInsights(base), []);
  const up = ins.buildInsights({ ...base, sales_week: 150000, sales_prev_week: 100000 });
  assert.equal(up[0].id, 'sales_up'); assert.match(up[0].title, /up 50%/);
  const down = ins.buildInsights({ ...base, sales_week: 50000, sales_prev_week: 100000 });
  assert.equal(down[0].severity, 'warn');
  assert.deepEqual(ins.buildInsights({ ...base, sales_week: 105000, sales_prev_week: 100000 }), [], 'a 5% wobble is not news');
  const debt = ins.buildInsights({ ...base, overdue_total: 600000, receivable_total: 1000000, top_debtor: { name: 'Esha', balance: 700000 } });
  assert.deepEqual(debt.map((i) => i.id), ['overdue', 'concentration']);
  assert.match(debt[0].title, /₹6,000 is overdue \(60%/);
  const cash = ins.buildInsights({ ...base, forecast_net: -250000, out_of_stock: 2, low_stock: 1 });
  assert.deepEqual(cash.map((i) => i.id), ['stock', 'cash_gap']);
});

test('health score is a weighted, explainable blend', () => {
  const good = ins.healthScore({ overdue_share: 0, stock_issue_share: 0, margin_pct: 40, sales_growth_pct: 20 });
  const bad = ins.healthScore({ overdue_share: 0.7, stock_issue_share: 0.4, margin_pct: 5, sales_growth_pct: -30 });
  assert.equal(good.label, 'healthy'); assert.equal(bad.label, 'needs attention');
  assert.equal(good.parts.length, 4);
  assert.ok(Math.abs(good.parts.reduce((s, p) => s + p.weight, 0) - 1) < 1e-9);
  assert.equal(ins.healthScore({ overdue_share: 0, stock_issue_share: 0, margin_pct: null, sales_growth_pct: null }).parts[2].score, 50);
});

const DB = process.env.TEST_DB;
test('forecast, risk and draft checks on PostgreSQL', { skip: DB ? false : 'set TEST_DB to run' }, async (t) => {
  const s = new PsqlSession(DB);
  t.after(() => s.close());
  const q = (text, params) => s.query(text, params);
  const TODAY = '2026-10-18';
  await s.run('TRUNCATE users, businesses, parties, items, invoices, payments, expenses, audit_logs RESTART IDENTITY CASCADE');
  const { rows: [u] } = await q(`INSERT INTO users (firebase_uid, email) VALUES ('i1','a@b.c') RETURNING id`);
  const { rows: [b] } = await q(`INSERT INTO businesses (owner_user_id, name, gst_registered, state_code) VALUES ($1,'Shop',true,'27') RETURNING *`, [u.id]);
  const party = async (name, extra = {}) => (await q(`INSERT INTO parties (business_id, name, gstin, gst_registered) VALUES ($1,$2,$3,$4) RETURNING id`, [b.id, name, extra.gstin || '', !!extra.reg])).rows[0].id;
  let no = 0;
  const inv = async (partyId, total, date, due, status = 'unpaid') => (await q(
    `INSERT INTO invoices (business_id, doc_type, affects_books, invoice_no, invoice_date, due_date, party_id, subtotal, taxable_value, grand_total, status)
     VALUES ($1,'gstInvoice',true,$2,$3,$4,$5,$6,$6,$6,$7) RETURNING id`, [b.id, `INV-${++no}`, date, due, partyId, total, status])).rows[0].id;
  const asha = await party('Asha'), bharat = await party('Bharat');
  // Asha has always paid on the due date
  const old = await inv(asha, 50000, '2026-08-01', '2026-08-15', 'paid');
  await q(`UPDATE invoices SET amount_paid = 50000 WHERE id = $1`, [old]);
  const pay = (await q(`INSERT INTO payments (business_id, party_id, payment_date, amount, mode) VALUES ($1,$2,'2026-08-15',50000,'upi') RETURNING id`, [b.id, asha])).rows[0].id;
  await q(`INSERT INTO payment_allocations (payment_id, invoice_id, amount) VALUES ($1,$2,50000)`, [pay, old]);
  await inv(asha, 100000, '2026-10-10', '2026-10-23');          // due in 5 days
  await inv(bharat, 200000, '2026-09-01', '2026-10-08');        // 10 days overdue, no history
  await q(`INSERT INTO expenses (business_id, category, amount, entry_date, recurring, next_due, mode) VALUES ($1,'Rent',50000,'2026-09-25','monthly','2026-10-25','bank')`, [b.id]);

  await t.test('risk detail explains itself', async () => {
    const a = await ins.partyRisk(s, b.id, asha);
    assert.equal(a.label, 'low'); assert.ok(a.reasons.some((r) => /on time/.test(r)));
    const x = await ins.partyRisk(s, b.id, bharat);
    assert.ok(x.score > a.score); assert.ok(x.reasons.some((r) => /overdue/.test(r)));
  });

  await t.test('forecast weights money by reliability and puts rent in the right week', async () => {
    const f = await ins.cashForecast(s, b.id, { today: TODAY, days: 28 });
    assert.equal(f.buckets.length, 4);
    assert.equal(f.buckets[0].expected_in > 90000 && f.buckets[0].expected_in < 100000 + 100000, true);
    // Asha's 100,000 (due Oct 23 = week 1) at 98%, Bharat's overdue 200,000 at about 0.8 * 0.5
    const asha = Math.round(100000 * 0.98);
    assert.ok(f.buckets[0].expected_in > asha + 60000 && f.buckets[0].expected_in < asha + 100000, `week 1 in = ${f.buckets[0].expected_in}`);
    assert.equal(f.buckets[1].expected_out >= 50000, true, 'rent due Oct 25 lands in week 2');
    assert.equal(f.buckets[0].expected_out < 50000, true);
    assert.equal(f.net, f.expected_in - f.expected_out);
    assert.equal(f.already_overdue, 200000);
  });

  await t.test('business insights run end to end', async () => {
    const r = await ins.businessInsights(s, b.id, { today: TODAY });
    const ids = r.insights.map((i) => i.id);
    assert.ok(ids.includes('overdue'));
    assert.ok(ids.includes('concentration'), 'Bharat owes 200,000 of 300,000');
  });

  await t.test('draft checks: duplicate, bad GSTIN, missing HSN, below cost, tax mismatch', async () => {
    const badGstin = await party('Dev', { gstin: '27AAAAA0000A1Z5', reg: true });
    assert.equal(isValidGstin('27AAAAA0000A1Z5'), false);
    const item = (await q(`INSERT INTO items (business_id, name, purchase_price, selling_price, gst_rate, gst_enabled) VALUES ($1,'Charger',30000,50000,18,true) RETURNING id`, [b.id])).rows[0].id;
    const id = await inv(badGstin, 59000, TODAY, TODAY);
    const r = await ins.checkInvoiceDraft(s, b, { party_id: badGstin, total: 59000, gst_enabled: true,
      lines: [{ item_id: item, name: 'Charger', rate: 20000, gst_slab: 12, hsn: '', tax_inclusive: false }] });
    assert.equal(r.ok, false);
    assert.deepEqual(r.warnings.map((w) => w.code).sort(), ['bad_gstin', 'below_cost', 'duplicate', 'missing_hsn', 'tax_mismatch']);
    const clean = await ins.checkInvoiceDraft(s, b, { party_id: asha, total: 1, gst_enabled: false, lines: [{ name: 'x', rate: 1, gst_slab: 0 }] });
    assert.deepEqual(clean, { ok: true, warnings: [] });
    assert.ok(id);
  });
});
