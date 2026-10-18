/**
 * Invoice business logic. Every function takes a database client so it can run inside the caller's transaction.
 * (Kept apart from the Express route so it can be tested directly against PostgreSQL.)
 */
const { notFound, badRequest, conflict } = require('../utils/errors');
const { computeInvoice } = require('../utils/invoiceMath');
const { stateCodeFromName } = require('../utils/states');
const { normalizeMode, isCreditMethod, termDays } = require('../utils/payments');
const { todayIST } = require('../utils/time');
const { recordPayment } = require('./payments');
const { BALANCE_SQL } = require('./partyQueries');
const { allowsNegativeStock } = require('./itemQueries');
const { audit } = require('../utils/audit');

const DOC_TYPES = ['gstInvoice', 'retailInvoice', 'estimate', 'proforma', 'deliveryChallan'];
const BOOK_TYPES = ['gstInvoice', 'retailInvoice'];            // these move stock and create receivables
const SERIES = { gstInvoice: 'INV', retailInvoice: 'INV', estimate: 'EST', proforma: 'PRO', deliveryChallan: 'DC' };

const addDays = (iso, n) => {
  const d = new Date(`${iso}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};
const rupees = (paise) => `₹${(paise / 100).toFixed(2)}`;

/** consume=true takes the next number (row-locked until commit); false only previews it. */
async function nextNumber(client, businessId, docType, { consume }) {
  const series = SERIES[docType];
  if (consume) {
    const { rows } = await client.query(
      `INSERT INTO document_sequences (business_id, series, last_number) VALUES ($1,$2,1)
       ON CONFLICT (business_id, series) DO UPDATE SET last_number = document_sequences.last_number + 1
       RETURNING last_number`, [businessId, series]);
    return `${series}-${String(rows[0].last_number).padStart(5, '0')}`;
  }
  const { rows } = await client.query('SELECT last_number FROM document_sequences WHERE business_id=$1 AND series=$2', [businessId, series]);
  return `${series}-${String((rows[0]?.last_number || 0) + 1).padStart(5, '0')}`;
}

async function createInvoice(c, { biz, userId, body: b }) {
  // Offline billing: the phone may push the same document twice. A repeated client_ref returns the invoice already saved.
  if (b.client_ref) {
    const { rows: dup } = await c.query('SELECT id FROM invoices WHERE business_id = $1 AND client_ref = $2', [biz.id, b.client_ref]);
    if (dup[0]) return dup[0].id;
  }
  const affectsBooks = BOOK_TYPES.includes(b.doc_type);
  const invoiceDate = b.invoice_date || todayIST();

  // 1. Party (tenant-checked, locked so the credit-limit check cannot race another invoice)
  let party = null;
  if (b.party_id) {
    const { rows } = await c.query(
      `SELECT p.*, (${BALANCE_SQL}) AS balance FROM parties p WHERE p.id = $1 AND p.business_id = $2 AND p.is_active FOR UPDATE OF p`,
      [b.party_id, biz.id]);
    party = rows[0];
    if (!party) throw notFound('Party not found');
  }

  // 2. GST: only for GST-registered businesses; tax type from place of supply
  const gstEnabled = !!b.gst_enabled && !!biz.gst_registered;
  const placeOfSupply = (party && stateCodeFromName(party.state)) || biz.state_code || null;
  const interstate = gstEnabled && !!placeOfSupply && !!biz.state_code && placeOfSupply !== biz.state_code;

  // 3. Items (tenant-checked, locked in id order to avoid deadlocks)
  const itemIds = [...new Set(b.lines.filter((l) => l.item_id).map((l) => l.item_id))].sort((x, y) => x - y);
  const items = new Map();
  if (itemIds.length) {
    const { rows } = await c.query('SELECT * FROM items WHERE business_id = $1 AND id = ANY($2::bigint[]) ORDER BY id FOR UPDATE', [biz.id, itemIds]);
    rows.forEach((r) => items.set(r.id, r));
    if (rows.length !== itemIds.length) throw badRequest('One or more items were not found');
  }

  // 4. Money maths (pure, server-side)
  const calc = computeInvoice(b.lines, { gstEnabled, interstate });

  // 5. Stock check, aggregated per item so the same item on two lines is checked together
  if (affectsBooks && !allowsNegativeStock(biz)) {
    const need = new Map();
    b.lines.forEach((l) => {
      const it = l.item_id ? items.get(l.item_id) : null;
      if (it && it.stock_enabled) need.set(it.id, (need.get(it.id) || 0) + l.qty);
    });
    if (need.size) {
      const { rows } = await c.query(
        `SELECT item_id, SUM(qty_in - qty_out) AS stock FROM stock_movements WHERE item_id = ANY($1::bigint[]) GROUP BY item_id`,
        [[...need.keys()]]);
      const stock = new Map(rows.map((r) => [r.item_id, r.stock]));
      for (const [itemId, qty] of need) {
        const have = stock.get(itemId) || 0;
        if (have < qty) throw conflict(`Not enough stock for "${items.get(itemId).name}": ${have} in stock, ${qty} needed`);
      }
    }
  }

  // 6. Payment at the counter, and the credit limit on what stays unpaid
  let paid = 0;
  if (affectsBooks) {
    paid = b.paid_amount !== undefined ? b.paid_amount : isCreditMethod(b.payment_method) ? 0 : calc.grand_total;
    if (paid > calc.grand_total) throw badRequest('Payment cannot be more than the invoice total');
    if (!party && paid < calc.grand_total) throw badRequest('Cash / walk-in sales must be paid in full. Select a customer to sell on credit.');
    if (party && party.credit_limit > 0) {
      const after = party.balance + calc.grand_total - paid;
      if (after > party.credit_limit) {
        throw conflict(`Credit limit exceeded for ${party.name}: limit ${rupees(party.credit_limit)}, balance would be ${rupees(after)}`);
      }
    }
  }

  // 7. Number, due date
  const invoiceNo = await nextNumber(c, biz.id, b.doc_type, { consume: true });
  let dueDate = b.due_date || null;
  if (!dueDate && party && affectsBooks && paid < calc.grand_total) {
    const days = termDays(party.payment_term);
    if (days > 0) dueDate = addDays(invoiceDate, days);
  }

  // 8. Save invoice + lines
  const status = !affectsBooks ? 'open' : calc.grand_total === 0 ? 'paid' : 'unpaid';
  const { rows: inv } = await c.query(
    `INSERT INTO invoices (business_id, doc_type, affects_books, invoice_no, invoice_date, due_date, party_id, cash_customer,
        party_name, party_phone, party_gst_registered, business_name, business_address, business_gstin, business_state, currency,
        gst_enabled, place_of_supply, is_interstate, payment_method, notes, terms, subtotal, discount_total, taxable_value,
        cgst, sgst, igst, tax_total, grand_total, amount_paid, status, created_by, client_ref)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,0,$31,$32,$33)
     RETURNING id`,
    [biz.id, b.doc_type, affectsBooks, invoiceNo, invoiceDate, dueDate, party ? party.id : null, !!b.cash_customer,
     party ? party.name : b.cash_customer ? 'Cash Customer' : '', party ? party.phone : '', party ? party.gst_registered : false,
     biz.name, biz.address || '', biz.gstin || '', biz.state || '', biz.currency || 'INR',
     gstEnabled, placeOfSupply, interstate, b.payment_method, b.notes || '', b.terms || '', calc.subtotal, calc.discount_total,
     calc.taxable_value, calc.cgst, calc.sgst, calc.igst, calc.tax_total, calc.grand_total, status, userId, b.client_ref || null]);
  const invoiceId = inv[0].id;

  for (let i = 0; i < b.lines.length; i++) {
    const l = b.lines[i];
    const r = calc.lines[i];
    await c.query(
      `INSERT INTO invoice_lines (invoice_id, item_id, name, unit, hsn, gst_slab, qty, rate, discount_is_percent, discount_value,
          line_base, discount_amount, taxable_value, tax_amount, cgst, sgst, igst, line_total)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)`,
      [invoiceId, l.item_id || null, l.name, l.unit || 'pcs', l.hsn || '', gstEnabled ? l.gst_slab || 0 : 0, l.qty, l.rate,
       l.discount_is_percent !== false, l.discount_value || 0, r.line_base, r.discount_amount, r.taxable_value, r.tax_amount,
       r.cgst, r.sgst, r.igst, r.line_total]);
    const it = l.item_id ? items.get(l.item_id) : null;
    if (affectsBooks && it && it.stock_enabled) {
      await c.query(
        `INSERT INTO stock_movements (business_id, item_id, qty_out, reason, ref_type, ref_id, created_by)
         VALUES ($1,$2,$3,'sale','invoice',$4,$5)`, [biz.id, it.id, l.qty, invoiceId, userId]);
    }
  }

  // 9. Payment received now
  if (paid > 0) {
    await recordPayment(c, {
      businessId: biz.id, userId, partyId: party ? party.id : null, amount: paid,
      mode: normalizeMode(b.payment_method), paymentDate: invoiceDate, referenceNo: '', notes: `Paid with ${invoiceNo}`,
      allocations: [{ invoice_id: invoiceId, amount: paid }],   // settles THIS invoice, not older ones
    });
  }
  await audit(c, { businessId: biz.id, userId, entity: 'invoice', entityId: invoiceId, action: 'create',
    details: { invoice_no: invoiceNo, grand_total: calc.grand_total } });
  return invoiceId;
}

async function loadInvoice(client, businessId, id) {
  const { rows } = await client.query(
    `SELECT i.*, i.grand_total - i.amount_paid AS balance_due FROM invoices i WHERE i.id = $1 AND i.business_id = $2`, [id, businessId]);
  if (!rows[0]) throw notFound('Invoice not found');
  const { rows: lines } = await client.query('SELECT * FROM invoice_lines WHERE invoice_id = $1 ORDER BY id', [id]);
  const { rows: payments } = await client.query(
    `SELECT p.id, p.payment_date, p.mode, p.reference_no, pa.amount FROM payment_allocations pa
       JOIN payments p ON p.id = pa.payment_id WHERE pa.invoice_id = $1 ORDER BY p.created_at, p.id`, [id]);
  return { ...rows[0], lines, payments };
}

/**
 * Cancel an invoice: stock goes back, and it stops counting as a sale or receivable.
 * Money already received: walk-in cash is treated as handed back (payment removed); a customer's payment stays on
 * their account as an advance. Proper refunds and credit notes arrive with the Returns module in Phase 2.
 */
async function cancelInvoice(c, { biz, userId, id, reason }) {
  const { rows } = await c.query('SELECT * FROM invoices WHERE id=$1 AND business_id=$2 FOR UPDATE', [id, biz.id]);
  const inv = rows[0];
  if (!inv) throw notFound('Invoice not found');
  if (inv.status === 'cancelled') throw conflict('Invoice is already cancelled');

  let refunded = 0;
  if (inv.affects_books) {
    await c.query(
      `INSERT INTO stock_movements (business_id, item_id, qty_in, reason, ref_type, ref_id, created_by)
       SELECT $1, l.item_id, l.qty, 'sale_cancel', 'invoice', $2, $3
         FROM invoice_lines l JOIN items it ON it.id = l.item_id
        WHERE l.invoice_id = $2 AND it.stock_enabled`, [biz.id, id, userId]);

    const { rows: allocs } = await c.query(
      `SELECT pa.id, pa.amount, pa.payment_id, p.party_id FROM payment_allocations pa
         JOIN payments p ON p.id = pa.payment_id WHERE pa.invoice_id = $1`, [id]);
    for (const a of allocs) {
      await c.query('DELETE FROM payment_allocations WHERE id = $1', [a.id]);
      if (a.party_id === null) {
        refunded += a.amount;
        await c.query('DELETE FROM payments WHERE id = $1', [a.payment_id]);   // walk-in cash handed back
      }
    }
  }
  await c.query(
    `UPDATE invoices SET status='cancelled', amount_paid=0, cancelled_at=now(), cancel_reason=$2, updated_at=now() WHERE id=$1`,
    [id, reason]);
  await audit(c, { businessId: biz.id, userId, entity: 'invoice', entityId: id, action: 'cancel',
    details: { reason, invoice_no: inv.invoice_no, was_paid: inv.amount_paid, cash_refunded: refunded } });
}

module.exports = { DOC_TYPES, BOOK_TYPES, nextNumber, createInvoice, loadInvoice, cancelInvoice };
