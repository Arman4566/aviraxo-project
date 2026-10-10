// Runs the real invoice/payment services against a real PostgreSQL database.
//   TEST_DB=aviraxo_it npm test      (database must exist and have db/schema.sql applied; it is wiped first)
// Skipped when TEST_DB is not set.
const test = require('node:test');
const assert = require('node:assert/strict');
const { PsqlSession, withTransaction } = require('./helpers/psqlClient');
const { createInvoice, cancelInvoice, loadInvoice, nextNumber } = require('../src/services/invoices');
const { recordPayment } = require('../src/services/payments');
const { PARTY_SELECT, partyJson } = require('../src/services/partyQueries');
const { ITEM_SELECT, itemJson } = require('../src/services/itemQueries');

const DB = process.env.TEST_DB;
const skip = DB ? false : 'set TEST_DB to run';

const line = (o) => ({ unit: 'pcs', hsn: '', gst_slab: 18, discount_is_percent: true, discount_value: 0, tax_inclusive: false, ...o });
const body = (o) => ({ cash_customer: false, payment_method: 'Cash', gst_enabled: true, notes: '', terms: '', ...o });

test('Phase 1 services on PostgreSQL', { skip }, async (t) => {
  const s = new PsqlSession(DB);
  t.after(() => s.close());
  const q = (text, params) => s.query(text, params);
  const tx = (fn) => withTransaction(s, fn);

  await s.run('TRUNCATE users, businesses, parties, items, invoices, payments, audit_logs RESTART IDENTITY CASCADE');
  const { rows: [u] } = await q(`INSERT INTO users (firebase_uid, email) VALUES ('t1','a@b.c') RETURNING id`);
  const { rows: [b] } = await q(
    `INSERT INTO businesses (owner_user_id, name, gst_registered, gstin, state, state_code, settings)
     VALUES ($1,'Ramesh Electronics',true,'27AAPFU0939F1ZV','Maharashtra','27','{}') RETURNING *`, [u.id]);
  const { rows: [u2] } = await q(`INSERT INTO users (firebase_uid, email) VALUES ('t2','x@y.z') RETURNING *`);
  const { rows: [b2] } = await q(`INSERT INTO businesses (owner_user_id, name, state_code) VALUES ($1,'Other Shop','27') RETURNING *`, [u2.id]);

  const mkItem = async (name, { stock = 0, stockEnabled = true, biz = b } = {}) => {
    const { rows: [i] } = await q(
      `INSERT INTO items (business_id, name, selling_price, gst_rate, gst_enabled, stock_enabled) VALUES ($1,$2,50000,18,true,$3) RETURNING id`,
      [biz.id, name, stockEnabled]);
    if (stock > 0) await q(`INSERT INTO stock_movements (business_id, item_id, qty_in, reason) VALUES ($1,$2,$3,'opening')`, [biz.id, i.id, stock]);
    return i.id;
  };
  const mkParty = async (name, { state = 'Maharashtra', limit = 0, term = 'Immediate', opening = 0, biz = b } = {}) => {
    const { rows: [p] } = await q(
      `INSERT INTO parties (business_id, name, state, credit_limit, payment_term, opening_balance) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id`,
      [biz.id, name, state, limit, term, opening]);
    return p.id;
  };
  const stockOf = async (itemId) => (await q(`${ITEM_SELECT} WHERE i.business_id = $1 AND i.id = $2`, [b.id, itemId])).rows[0].stock_qty;
  const partyBalance = async (id) => partyJson((await q(`${PARTY_SELECT} WHERE p.business_id = $1 AND p.id = $2`, [b.id, id])).rows[0]).balance;
  const create = (o) => tx((c) => createInvoice(c, { biz: b, userId: u.id, body: body(o) }).then((id) => loadInvoice(c, b.id, id)));

  const charger = await mkItem('Charger', { stock: 10 });
  const service = await mkItem('Repair visit', { stockEnabled: false });
  const suresh = await mkParty('Suresh (Mumbai)', { limit: 500000, term: 'Net 15' });
  const kiran = await mkParty('Kiran (Ahmedabad)', { state: 'Gujarat' });

  await t.test('cash sale to a walk-in: GST split, stock out, paid, numbered', async () => {
    const inv = await create({ doc_type: 'gstInvoice', cash_customer: true, invoice_date: '2026-10-09', lines: [line({ item_id: charger, name: 'Charger', qty: 2, rate: 50000 })] });
    assert.equal(inv.invoice_no, 'INV-00001');
    assert.deepEqual([inv.subtotal, inv.taxable_value, inv.cgst, inv.sgst, inv.igst, inv.grand_total], [100000, 100000, 9000, 9000, 0, 118000]);
    assert.deepEqual([inv.status, inv.amount_paid, inv.balance_due, inv.party_name], ['paid', 118000, 0, 'Cash Customer']);
    assert.equal(inv.payments.length, 1);
    assert.equal(await stockOf(charger), 8);
  });

  await t.test('credit sale with discount: unpaid, due date from Net 15, party balance, stock', async () => {
    const inv = await create({ doc_type: 'gstInvoice', party_id: suresh, payment_method: 'Credit (Pay Later)', invoice_date: '2026-10-09',
      lines: [line({ item_id: charger, name: 'Charger', qty: 3, rate: 50000, discount_value: 10 })] });
    assert.equal(inv.invoice_no, 'INV-00002');
    assert.deepEqual([inv.grand_total, inv.status, inv.amount_paid, inv.due_date], [159300, 'unpaid', 0, '2026-10-24']);
    assert.equal(await partyBalance(suresh), 159300);
    assert.equal(await stockOf(charger), 5);
  });

  await t.test('interstate customer gets IGST only', async () => {
    const inv = await create({ doc_type: 'gstInvoice', party_id: kiran, payment_method: 'UPI', lines: [line({ item_id: charger, name: 'Charger', qty: 1, rate: 50000 })] });
    assert.deepEqual([inv.is_interstate, inv.place_of_supply, inv.cgst, inv.sgst, inv.igst, inv.grand_total], [true, '24', 0, 0, 9000, 59000]);
    assert.equal(await stockOf(charger), 4);
  });

  await t.test('payments settle the oldest invoice first, then the next', async () => {
    const r1 = await tx((c) => recordPayment(c, { businessId: b.id, userId: u.id, partyId: suresh, amount: 100000, mode: 'upi', paymentDate: '2026-10-10' }));
    assert.deepEqual([r1.allocated, r1.unallocated], [100000, 0]);
    assert.equal((await q('SELECT status, amount_paid FROM invoices WHERE invoice_no = $1', ['INV-00002'])).rows[0].status, 'partial');
    assert.equal(await partyBalance(suresh), 59300);
    const r2 = await tx((c) => recordPayment(c, { businessId: b.id, userId: u.id, partyId: suresh, amount: 70000, mode: 'cash', paymentDate: '2026-10-11' }));
    assert.deepEqual([r2.allocated, r2.unallocated], [59300, 10700]);   // 10,700 stays as an advance
    assert.equal((await q('SELECT status FROM invoices WHERE invoice_no = $1', ['INV-00002'])).rows[0].status, 'paid');
    assert.equal(await partyBalance(suresh), -10700);
  });

  await t.test('selling more than the stock is refused and leaves nothing behind', async () => {
    const before = (await q('SELECT count(*) AS n FROM invoices')).rows[0].n;
    await assert.rejects(create({ doc_type: 'gstInvoice', cash_customer: true, lines: [line({ item_id: charger, name: 'Charger', qty: 99, rate: 50000 })] }), /Not enough stock/);
    assert.equal((await q('SELECT count(*) AS n FROM invoices')).rows[0].n, before);
    assert.equal(await stockOf(charger), 4);
    assert.equal((await nextNumber(s, b.id, 'gstInvoice', { consume: false })), 'INV-00004');   // number was not burned
  });

  await t.test('negative stock is allowed when the business setting says so', async () => {
    const lenient = { ...b, settings: { allowNegativeStock: true } };
    const id = await tx((c) => createInvoice(c, { biz: lenient, userId: u.id, body: body({ doc_type: 'gstInvoice', cash_customer: true, lines: [line({ item_id: charger, name: 'Charger', qty: 6, rate: 50000 })] }) }));
    assert.ok(id);
    assert.equal(await stockOf(charger), -2);
    await tx((c) => cancelInvoice(c, { biz: b, userId: u.id, id, reason: 'test cleanup' }));
    assert.equal(await stockOf(charger), 4);
  });

  await t.test('credit limit stops a sale that would push the balance over it', async () => {
    const limited = await mkParty('Limited Co', { limit: 100000 });
    await assert.rejects(
      create({ doc_type: 'gstInvoice', party_id: limited, payment_method: 'Credit', lines: [line({ item_id: charger, name: 'Charger', qty: 2, rate: 50000 })] }),
      /Credit limit exceeded/);
    const ok = await create({ doc_type: 'gstInvoice', party_id: limited, payment_method: 'Credit', lines: [line({ item_id: charger, name: 'Charger', qty: 1, rate: 50000, gst_slab: 0 })] });
    assert.equal(ok.grand_total, 50000);
  });

  await t.test('walk-in sales on credit are refused', async () => {
    await assert.rejects(create({ doc_type: 'gstInvoice', cash_customer: true, payment_method: 'Credit', lines: [line({ name: 'Service', rate: 1000, qty: 1 })] }), /paid in full/);
  });

  await t.test('estimate: separate numbering, no stock, no receivable, not payable', async () => {
    const stockBefore = await stockOf(charger);
    const balBefore = await partyBalance(suresh);
    const est = await create({ doc_type: 'estimate', party_id: suresh, lines: [line({ item_id: charger, name: 'Charger', qty: 2, rate: 50000 })] });
    assert.deepEqual([est.invoice_no, est.status, est.affects_books, est.grand_total], ['EST-00001', 'open', false, 118000]);
    assert.equal(await stockOf(charger), stockBefore);
    assert.equal(await partyBalance(suresh), balBefore);
    await assert.rejects(tx((c) => recordPayment(c, { businessId: b.id, userId: u.id, partyId: suresh, amount: 100, mode: 'cash', paymentDate: '2026-10-10',
      allocations: [{ invoice_id: est.id, amount: 100 }] })), /estimates or challans/);
  });

  await t.test('retail invoice without GST, services do not touch stock', async () => {
    const inv = await create({ doc_type: 'retailInvoice', gst_enabled: false, cash_customer: true, lines: [line({ item_id: service, name: 'Repair visit', qty: 1, rate: 30000 })] });
    assert.deepEqual([inv.tax_total, inv.grand_total, inv.gst_enabled], [0, 30000, false]);
    assert.equal((await q('SELECT count(*) AS n FROM stock_movements WHERE item_id = $1', [service])).rows[0].n, 0);
  });

  await t.test('cancelling a paid walk-in invoice restores stock and removes the cash', async () => {
    const stockBefore = await stockOf(charger);
    const inv = await create({ doc_type: 'gstInvoice', cash_customer: true, lines: [line({ item_id: charger, name: 'Charger', qty: 1, rate: 50000 })] });
    await tx((c) => cancelInvoice(c, { biz: b, userId: u.id, id: inv.id, reason: 'customer changed mind' }));
    const after = await loadInvoice(s, b.id, inv.id);
    assert.deepEqual([after.status, after.amount_paid, after.payments.length], ['cancelled', 0, 0]);
    assert.equal(await stockOf(charger), stockBefore);
    await assert.rejects(tx((c) => cancelInvoice(c, { biz: b, userId: u.id, id: inv.id, reason: 'again' })), /already cancelled/);
  });

  await t.test('cancelling a customer invoice keeps their payment as an advance', async () => {
    const mina = await mkParty('Mina');
    const inv = await create({ doc_type: 'gstInvoice', party_id: mina, payment_method: 'UPI', lines: [line({ name: 'Consulting', qty: 1, rate: 100000, gst_slab: 0 })] });
    assert.equal(await partyBalance(mina), 0);
    await tx((c) => cancelInvoice(c, { biz: b, userId: u.id, id: inv.id, reason: 'billing error' }));
    assert.equal(await partyBalance(mina), -100000);
  });

  await t.test('tenant isolation: another business cannot use this business items or parties', async () => {
    const foreignItem = await mkItem('Foreign', { stock: 5, biz: b2 });
    const foreignParty = await mkParty('Foreign Party', { biz: b2 });
    await assert.rejects(create({ doc_type: 'gstInvoice', cash_customer: true, lines: [line({ item_id: foreignItem, name: 'x', qty: 1, rate: 100 })] }), /items were not found/);
    await assert.rejects(create({ doc_type: 'gstInvoice', party_id: foreignParty, lines: [line({ name: 'x', qty: 1, rate: 100 })] }), /Party not found/);
  });

  await t.test('GST is forced off for a business that is not GST registered', async () => {
    const plain = { ...b, gst_registered: false };
    const id = await tx((c) => createInvoice(c, { biz: plain, userId: u.id, body: body({ doc_type: 'gstInvoice', cash_customer: true, lines: [line({ name: 'Pen', qty: 1, rate: 1000 })] }) }));
    assert.equal((await loadInvoice(s, b.id, id)).tax_total, 0);
  });

  await t.test('item stock counters follow the ledger (in/out totals, cancel nets out)', async () => {
    const it = itemJson((await q(`${ITEM_SELECT} WHERE i.business_id = $1 AND i.id = $2`, [b.id, charger])).rows[0]);
    assert.equal(it.stock_in_total, 10);
    assert.equal(it.stock_in_total - it.stock_out_total, it.stock_qty);
  });

  await t.test('database refuses an overpaid invoice', async () => {
    await assert.rejects(q(`UPDATE invoices SET amount_paid = grand_total + 1 WHERE invoice_no = 'INV-00001'`), (e) => e.code === '23514');
  });
});
