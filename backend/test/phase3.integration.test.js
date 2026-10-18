// Expenses, offline idempotency, conversions, inventory alerts, backup/restore, finance reports and staff roles on PostgreSQL.
const test = require('node:test');
const assert = require('node:assert/strict');
const { PsqlSession, withTransaction } = require('./helpers/psqlClient');
const { createInvoice, loadInvoice } = require('../src/services/invoices');
const { recordPayment } = require('../src/services/payments');
const { isValidGstin } = require('../src/utils/invoiceMath');
const { PARTY_SELECT, partyJson } = require('../src/services/partyQueries');
const exp = require('../src/services/expenses');
const inv = require('../src/services/inventory');
const docs = require('../src/services/documents');
const backup = require('../src/services/backup');
const fin = require('../src/services/finance');
const staff = require('../src/services/staff');
const { can, PERMISSIONS } = require('../src/utils/permissions');
const { todayIST } = require('../src/utils/time');

const DB = process.env.TEST_DB;
const skip = DB ? false : 'set TEST_DB to run';
const RANGE = { from: '2026-10-01', to: '2026-10-31' };

const withCheckChar = (prefix) => {
  for (const ch of '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ') if (isValidGstin(prefix + ch)) return prefix + ch;
  throw new Error('no checksum char');
};
const line = (o) => ({ unit: 'pcs', hsn: '', gst_slab: 18, discount_is_percent: true, discount_value: 0, tax_inclusive: false, ...o });
const body = (o) => ({ cash_customer: false, payment_method: 'Cash', gst_enabled: true, notes: '', terms: '', ...o });

test('Phase 3-5 services on PostgreSQL', { skip }, async (t) => {
  const s = new PsqlSession(DB);
  t.after(() => s.close());
  const q = (text, params) => s.query(text, params);
  const tx = (fn) => withTransaction(s, fn);

  await s.run('TRUNCATE users, businesses, parties, items, invoices, payments, expenses, staff_invites, audit_logs, reminder_rules, reminder_log, payment_promises RESTART IDENTITY CASCADE');
  const { rows: [u] } = await q(`INSERT INTO users (firebase_uid, email) VALUES ('p1','owner@shop.in') RETURNING id`);
  const bizGstin = withCheckChar('27AAPFU0939F1Z');
  const { rows: [b] } = await q(
    `INSERT INTO businesses (owner_user_id, name, gst_registered, gstin, state, state_code, settings)
     VALUES ($1,'Ramesh Electronics',true,$2,'Maharashtra','27','{"openingBalances":{"cash":500000}}') RETURNING *`, [u.id, bizGstin]);
  await q(`INSERT INTO business_users (business_id, user_id, role) VALUES ($1,$2,'owner')`, [b.id, u.id]);

  const mkItem = async (name, { buy, sell, stock, low = 0, hsn = '', barcode = '', stockEnabled = true }) => {
    const { rows: [i] } = await q(
      `INSERT INTO items (business_id, name, purchase_price, selling_price, gst_rate, gst_enabled, stock_enabled, low_stock_level, hsn, barcode)
       VALUES ($1,$2,$3,$4,18,true,$5,$6,$7,$8) RETURNING id`, [b.id, name, buy, sell, stockEnabled, low, hsn, barcode]);
    if (stock) await q(`INSERT INTO stock_movements (business_id, item_id, qty_in, reason) VALUES ($1,$2,$3,'opening')`, [b.id, i.id, stock]);
    return i.id;
  };
  const charger = await mkItem('Charger', { buy: 30000, sell: 50000, stock: 10, low: 3, hsn: '8504', barcode: '8901234567890' });
  const cable = await mkItem('Cable', { buy: 5000, sell: 10000, stock: 2, low: 5, hsn: '8544' });
  const mkParty = async (name, state, gstin = '') =>
    (await q(`INSERT INTO parties (business_id, name, state, gstin, gst_registered, payment_term) VALUES ($1,$2,$3,$4,$5,'Net 15') RETURNING id`, [b.id, name, state, gstin, !!gstin])).rows[0].id;
  const suresh = await mkParty('Suresh Traders', 'Maharashtra', withCheckChar('27AABCS1429B1Z'));
  const kiran = await mkParty('Kiran Stores', 'Gujarat');
  const create = (o) => tx((c) => createInvoice(c, { biz: b, userId: u.id, body: body(o) }).then((id) => loadInvoice(c, b.id, id)));

  await t.test('offline pushes are idempotent: same client_ref -> same invoice, no burnt number, no double payment', async () => {
    const a = await create({ doc_type: 'gstInvoice', cash_customer: true, invoice_date: '2026-10-05', client_ref: 'offline-0001-aaaa',
      lines: [line({ item_id: charger, name: 'Charger', hsn: '8504', qty: 2, rate: 50000 })] });
    const again = await create({ doc_type: 'gstInvoice', cash_customer: true, invoice_date: '2026-10-05', client_ref: 'offline-0001-aaaa',
      lines: [line({ item_id: charger, name: 'Charger', hsn: '8504', qty: 2, rate: 50000 })] });
    assert.equal(a.id, again.id);
    assert.equal(a.invoice_no, 'INV-00001');
    assert.equal((await q('SELECT count(*) AS n FROM invoices')).rows[0].n, 1);
    assert.equal(a.grand_total, 118000);
    const p1 = await tx((c) => recordPayment(c, { businessId: b.id, userId: u.id, partyId: suresh, amount: 1000, mode: 'cash', paymentDate: '2026-10-05', clientRef: 'offline-pay-0001' }));
    const p2 = await tx((c) => recordPayment(c, { businessId: b.id, userId: u.id, partyId: suresh, amount: 1000, mode: 'cash', paymentDate: '2026-10-05', clientRef: 'offline-pay-0001' }));
    assert.equal(p1.payment.id, p2.payment.id);
    assert.equal(p2.duplicate, true);
    assert.equal((await q(`SELECT count(*) AS n FROM payments WHERE party_id = $1`, [suresh])).rows[0].n, 1);
    // undo the advance so later numbers stay simple
    await q('DELETE FROM payments WHERE party_id = $1', [suresh]);
  });

  await t.test('more sales for the month', async () => {
    const i2 = await create({ doc_type: 'gstInvoice', party_id: suresh, payment_method: 'Credit (Pay Later)', invoice_date: '2026-10-06', lines: [line({ item_id: charger, name: 'Charger', hsn: '8504', qty: 3, rate: 50000 })] });
    assert.deepEqual([i2.grand_total, i2.cgst, i2.sgst], [177000, 13500, 13500]);
    const i3 = await create({ doc_type: 'gstInvoice', party_id: kiran, payment_method: 'UPI', invoice_date: '2026-10-07', lines: [line({ item_id: charger, name: 'Charger', hsn: '8504', qty: 1, rate: 50000 })] });
    assert.deepEqual([i3.grand_total, i3.igst], [59000, 9000]);
    const i4 = await create({ doc_type: 'gstInvoice', party_id: kiran, payment_method: 'Bank Transfer', invoice_date: '2026-10-08', lines: [line({ name: 'Bulk machinery order', qty: 1, rate: 30000000 })] });
    assert.equal(i4.grand_total, 35400000);
  });

  await t.test('expenses: validation, categories, idempotency and recurring entries run once per due date', async () => {
    await assert.rejects(tx((c) => exp.createExpense(c, { businessId: b.id, userId: u.id, body: { category: 'Tea', amount: 100, gst_amount: 200 } })), /GST cannot/);
    const rent = await tx((c) => exp.createExpense(c, { businessId: b.id, userId: u.id, body: { category: 'Rent', amount: 1000000, mode: 'bank', entry_date: '2026-10-15', recurring: 'monthly' } }));
    assert.equal(String(rent.next_due).slice(0, 10), '2026-11-15');
    await tx((c) => exp.createExpense(c, { businessId: b.id, userId: u.id, body: { category: 'Electricity', amount: 11800, gst_amount: 1800, mode: 'upi', entry_date: '2026-10-10', client_ref: 'offline-exp-0001' } }));
    const dup = await tx((c) => exp.createExpense(c, { businessId: b.id, userId: u.id, body: { category: 'Electricity', amount: 11800, gst_amount: 1800, mode: 'upi', entry_date: '2026-10-10', client_ref: 'offline-exp-0001' } }));
    assert.ok(dup.id);
    await tx((c) => exp.createExpense(c, { businessId: b.id, userId: u.id, body: { kind: 'income', category: 'Scrap sale', amount: 5000, mode: 'bank', entry_date: '2026-10-12' } }));
    const r1 = await tx((c) => exp.runRecurring(c, b.id, '2026-12-20'));
    const r2 = await tx((c) => exp.runRecurring(c, b.id, '2026-12-20'));
    assert.deepEqual([r1.created, r2.created], [2, 0]);                 // 15 Nov and 15 Dec
    assert.equal(String((await q('SELECT next_due FROM expenses WHERE id = $1', [rent.id])).rows[0].next_due).slice(0, 10), '2027-01-15');
    assert.equal(exp.addMonths('2026-01-31', 1), '2026-02-28');
    const sum = await exp.summary(s, b.id, RANGE);
    assert.equal(sum.total_expense, 1000000 + 11800);
    assert.equal(sum.total_income, 5000);
    assert.equal(sum.input_gst, 1800);
    const cats = await exp.categories(s, b.id);
    assert.ok(cats.includes('Rent') && cats.includes('Marketing'));
    const list = await exp.listExpenses(s, b.id, { ...RANGE, kind: 'expense' });
    assert.equal(list.length, 2);
    await assert.rejects(tx((c) => exp.deleteExpense(c, '00000000-0000-0000-0000-000000000000', 1)), /invalid input|not found/i);
  });

  await t.test('estimate converts to an invoice with the same total, once, even when entered tax-inclusive', async () => {
    const est = await create({ doc_type: 'estimate', party_id: suresh, lines: [line({ item_id: charger, name: 'Charger', hsn: '8504', qty: 1, rate: 59000, tax_inclusive: true })] });
    assert.equal(est.grand_total, 59000);
    const out = await tx((c) => docs.convertToInvoice(c, { biz: b, userId: u.id, id: est.id, invoiceDate: '2026-11-20' }));
    assert.equal(out.doc_type, 'gstInvoice');
    assert.equal(out.grand_total, 59000);
    assert.equal(out.status, 'unpaid');
    assert.equal(out.converted_from, est.id);
    assert.equal((await q('SELECT converted_to FROM invoices WHERE id = $1', [est.id])).rows[0].converted_to, out.id);
    await assert.rejects(tx((c) => docs.convertToInvoice(c, { biz: b, userId: u.id, id: est.id })), /already converted/);
    await assert.rejects(tx((c) => docs.convertToInvoice(c, { biz: b, userId: u.id, id: out.id })), /Only estimates/);
  });

  await t.test('low-stock alerts rank out/low items, suggest a reorder, and barcode lookup works', async () => {
    const r = await inv.lowStock(s, b.id);
    const names = r.alerts.map((a) => a.name);
    assert.deepEqual(names, ['Cable', 'Charger']);          // Cable 2 left (level 5), Charger 4-... = 3 left (level 3)
    const cableA = r.alerts.find((a) => a.name === 'Cable');
    assert.equal(cableA.status, 'low');
    assert.equal(cableA.suggested_reorder, 8);               // max(2*5, sold 0) - 2
    const charg = r.alerts.find((a) => a.name === 'Charger');
    assert.equal(typeof charg.sold_30d, 'number');
    assert.ok(charg.suggested_reorder >= 3, 'stock 3 against level 3: reorder up to twice the alert level');
    const found = await inv.byBarcode(s, b.id, '8901234567890');
    assert.equal(found.name, 'Charger');
    assert.equal(await inv.byBarcode(s, b.id, '000'), null);
  });

  await t.test('profit & loss: sales - cost of goods - expenses (input GST excluded) + other income', async () => {
    const pl = await fin.profitLoss(s, b, RANGE);
    assert.equal(pl.sales, 100000 + 150000 + 50000 + 30000000 + 0);   // the estimate-converted invoice is dated in November
    assert.equal(pl.cost_of_goods, (2 + 3 + 1) * 30000);
    assert.equal(pl.gross_profit, pl.sales - pl.cost_of_goods);
    assert.equal(pl.expenses, 1000000 + 10000);
    assert.equal(pl.other_income, 5000);
    assert.equal(pl.net_profit, pl.gross_profit - pl.expenses + pl.other_income);
    assert.equal(pl.lines_without_cost, 1);                          // the bulk order line has no item
  });

  await t.test('day book, cash & bank balances and cash flow', async () => {
    const d = await fin.dayBook(s, b.id, '2026-10-05');
    assert.deepEqual(d.entries.map((e) => e.type), ['sale', 'payment_in']);
    assert.deepEqual([d.sales, d.money_in, d.money_out], [118000, 118000, 0]);
    const cb = await fin.cashAndBank(s, b);
    const get = (m) => cb.accounts.find((a) => a.mode === m);
    assert.equal(get('cash').balance, 500000 + 118000);
    assert.equal(get('bank').balance, 5000 + 35400000 - 1000000 - 1000000 - 1000000);   // bulk order received by bank; rent 3 times (Oct, Nov, Dec)
    assert.equal(get('upi').balance, 59000 - 11800);
    const cf = await fin.cashFlow(s, b.id, RANGE);
    assert.equal(cf.money_in, 118000 + 59000 + 35400000 + 5000);
    assert.equal(cf.money_out, 1000000 + 11800);
    assert.equal(cf.net, cf.money_in - cf.money_out);
  });

  await t.test('GSTR-1 sections: B2B, B2C large, B2C small, HSN, documents', async () => {
    const g = await fin.gstr1(s, b, RANGE);
    assert.equal(g.b2b.length, 1);
    assert.equal(g.b2b[0].gstin, suresh && (await q('SELECT gstin FROM parties WHERE id = $1', [suresh])).rows[0].gstin);
    assert.deepEqual(g.b2b[0].items, [{ rate: 18, taxable_value: 150000, igst: 0, cgst: 13500, sgst: 13500 }]);
    assert.equal(g.b2cl.length, 1);
    assert.equal(g.b2cl[0].items[0].igst, 5400000);
    assert.deepEqual(g.b2cs.map((r) => [r.place_of_supply, r.taxable_value, r.igst, r.cgst, r.sgst]).sort(), [['24', 50000, 9000, 0, 0], ['27', 100000, 0, 9000, 9000]]);
    const h = g.hsn.find((r) => r.hsn === '8504');
    assert.deepEqual([h.qty, h.taxable_value, h.cgst], [6, 300000, 22500]);
    assert.equal(g.documents[0].series, 'INV');
    assert.equal(g.documents[0].total, 4);
    assert.ok(g.warnings.some((w) => /HSN/.test(w)));
    // everything is accounted for exactly once
    const all = g.b2b.flatMap((x) => x.items).concat(g.b2cl.flatMap((x) => x.items), g.b2cs);
    assert.equal(all.reduce((a, r) => a + r.taxable_value, 0), g.totals.taxable_value);
  });

  await t.test('GSTR-3B working numbers', async () => {
    const g = await fin.gstr3b(s, b, RANGE);
    assert.deepEqual(g.outward_taxable, { taxable_value: 30300000, igst: 5409000, cgst: 22500, sgst: 22500 });
    assert.equal(g.interstate_unregistered.find((r) => r.place_of_supply === '24').igst, 5409000);
    assert.equal(g.itc_estimate, 1800);
    assert.equal(g.tax_payable_estimate, 5409000 + 22500 + 22500 - 1800);
  });

  await t.test('backup -> restore into an empty firm reproduces everything, and refuses non-empty ones', async () => {
    await q(`INSERT INTO reminder_rules (business_id, name, trigger_type, offset_days) VALUES ($1,'On due','on_due',0)`, [b.id]);
    const data = JSON.parse(JSON.stringify(await backup.exportAll(s, b)));      // through JSON, like a real file
    assert.equal(data.counts.invoices, 6);          // 4 sales + the estimate + the invoice it was converted into
    const { rows: [b2] } = await q(`INSERT INTO businesses (owner_user_id, name, gst_registered, state_code) VALUES ($1,'Ramesh Electronics (2nd firm)',true,'27') RETURNING *`, [u.id]);
    const res = await tx((c) => backup.restore(c, { biz: b2, userId: u.id, data }));
    assert.deepEqual(res.restored, data.counts);
    const count = async (table, biz) => (await q(`SELECT count(*) AS n FROM ${table} WHERE business_id = $1`, [biz.id])).rows[0].n;
    for (const tbl of ['parties', 'items', 'invoices', 'payments', 'stock_movements', 'expenses', 'reminder_rules']) assert.equal(await count(tbl, b2), await count(tbl, b), tbl);
    const bal = async (biz, name) => partyJson((await q(`${PARTY_SELECT} WHERE p.business_id = $1 AND p.name = $2`, [biz.id, name])).rows[0]).balance;
    assert.equal(await bal(b2, 'Suresh Traders'), await bal(b, 'Suresh Traders'));
    const stock = async (biz) => (await q(`SELECT COALESCE(SUM(qty_in - qty_out),0) AS n FROM stock_movements WHERE business_id = $1`, [biz.id])).rows[0].n;
    assert.equal(await stock(b2), await stock(b));
    const pl1 = await fin.profitLoss(s, b, RANGE), pl2 = await fin.profitLoss(s, b2, RANGE);
    assert.deepEqual([pl2.sales, pl2.net_profit], [pl1.sales, pl1.net_profit]);
    const lines = (await q(`SELECT count(*) AS n FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id WHERE i.business_id = $1`, [b2.id])).rows[0].n;
    assert.equal(lines, (await q(`SELECT count(*) AS n FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id WHERE i.business_id = $1`, [b.id])).rows[0].n);
    // numbering continues where the old firm stopped
    const next = await tx((c) => createInvoice(c, { biz: b2, userId: u.id, body: body({ doc_type: 'gstInvoice', cash_customer: true, lines: [line({ name: 'Misc', qty: 1, rate: 100 })] }) }).then((id) => loadInvoice(c, b2.id, id)));
    assert.equal(next.invoice_no, 'INV-00006');
    await assert.rejects(tx((c) => backup.restore(c, { biz: b2, userId: u.id, data })), /no data yet/);
    const { rows: [b3] } = await q(`INSERT INTO businesses (owner_user_id, name, state_code) VALUES ($1,'Empty firm','27') RETURNING *`, [u.id]);
    await assert.rejects(tx((c) => backup.restore(c, { biz: b3, userId: u.id, data: { app: 'other' } })), /not a Galla Pro backup/);
    await assert.rejects(tx((c) => backup.restore(c, { biz: b3, userId: u.id, data: { ...data, invoice_lines: [{ id: 1, invoice_id: 99999, name: 'x', qty: 1, rate: 1, line_base: 1, taxable_value: 1, line_total: 1 }] } })), /inconsistent/);
    assert.equal(await count('invoices', b3), 0, 'a failed restore leaves nothing behind');
  });

  await t.test('staff: invite, auto-join on sign-in, roles and permissions', async () => {
    await assert.rejects(tx((c) => staff.invite(c, { businessId: b.id, userId: u.id, email: 'nope', role: 'cashier' })), /valid email/);
    await assert.rejects(tx((c) => staff.invite(c, { businessId: b.id, userId: u.id, email: 'x@y.in', role: 'owner' })), /Role must be/);
    await tx((c) => staff.invite(c, { businessId: b.id, userId: u.id, email: 'Anil@Shop.in', role: 'cashier' }));
    await tx((c) => staff.invite(c, { businessId: b.id, userId: u.id, email: 'anil@shop.in', role: 'manager' }));      // re-invite replaces
    assert.equal((await staff.listStaff(s, b.id)).invites.length, 1);
    const { rows: [anil] } = await q(`INSERT INTO users (firebase_uid, email) VALUES ('p2','ANIL@shop.in') RETURNING id`);
    const joined = await tx((c) => staff.acceptInvitesFor(c, { userId: anil.id, email: 'ANIL@shop.in' }));
    assert.deepEqual(joined, [b.id]);
    const list = await staff.listStaff(s, b.id);
    assert.deepEqual(list.members.map((m) => m.role), ['owner', 'manager']);
    assert.equal(list.invites.length, 0);
    const mem = list.members[1];
    const changed = await tx((c) => staff.changeRole(c, b.id, mem.id, 'cashier'));
    assert.equal(changed.role, 'cashier');
    await assert.rejects(tx((c) => staff.changeRole(c, b.id, list.members[0].id, 'viewer')), /owner/);
    await assert.rejects(tx((c) => staff.removeMember(c, b.id, list.members[0].id)), /owner/);
    await tx((c) => staff.removeMember(c, b.id, mem.id));
    assert.equal((await staff.listStaff(s, b.id)).members.length, 1);

    assert.ok(can('owner', 'anything'));
    assert.ok(can('cashier', 'invoices.create') && !can('cashier', 'reports.view') && !can('cashier', 'expenses.manage') && !can('cashier', 'items.see_cost'));
    assert.ok(can('accountant', 'reports.gst') && !can('accountant', 'items.manage') && !can('accountant', 'staff.manage'));
    assert.ok(can('viewer', 'reports.view') && !can('viewer', 'invoices.create'));
    assert.ok(!can('stranger', 'dashboard.view'));
    assert.ok(!Object.values(PERMISSIONS).some((p, i) => i > 0 && p.includes('staff.manage')), 'only the owner manages staff');
  });
});
