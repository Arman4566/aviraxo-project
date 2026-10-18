// Turning an estimate / proforma / delivery challan into a real invoice.
const { notFound, badRequest, conflict } = require('../utils/errors');
const { computeInvoice } = require('../utils/invoiceMath');
const { createInvoice, loadInvoice, BOOK_TYPES } = require('./invoices');
const { todayIST } = require('../utils/time');

const CONVERTIBLE = ['estimate', 'proforma', 'deliveryChallan'];

async function convertToInvoice(c, { biz, userId, id, docType = 'gstInvoice', paymentMethod, invoiceDate, dueDate }) {
  if (!BOOK_TYPES.includes(docType)) throw badRequest('Can only convert into an invoice');
  const { rows: [src] } = await c.query('SELECT * FROM invoices WHERE id = $1 AND business_id = $2 FOR UPDATE', [id, biz.id]);
  if (!src) throw notFound('Document not found');
  if (!CONVERTIBLE.includes(src.doc_type)) throw badRequest('Only estimates, proformas and delivery challans can be converted');
  if (src.status === 'cancelled') throw conflict('This document is cancelled');
  if (src.converted_to) throw conflict('This document was already converted to an invoice');

  const { rows: lines } = await c.query('SELECT * FROM invoice_lines WHERE invoice_id = $1 ORDER BY id', [id]);
  const mk = (inclusive) => lines.map((l) => ({
    item_id: l.item_id, name: l.name, unit: l.unit, hsn: l.hsn, gst_slab: l.gst_slab, qty: l.qty, rate: l.rate,
    discount_is_percent: l.discount_is_percent, discount_value: l.discount_value, tax_inclusive: inclusive,
  }));
  // The original rate may have been entered tax-inclusive (not stored). Pick the reading that reproduces the old total exactly.
  const opts = { gstEnabled: src.gst_enabled, interstate: src.is_interstate };
  const lineSet = [false, true].map(mk).find((ls) => computeInvoice(ls, opts).grand_total === src.grand_total);
  if (!lineSet) throw conflict('Totals of this document cannot be reproduced; please create the invoice manually');

  const hasParty = !!src.party_id;
  const id2 = await createInvoice(c, {
    biz, userId, body: {
      doc_type: docType, party_id: src.party_id, cash_customer: src.cash_customer, invoice_date: invoiceDate || todayIST(), due_date: dueDate || null,
      payment_method: paymentMethod || (hasParty ? 'Credit (Pay Later)' : 'Cash'), gst_enabled: src.gst_enabled,
      notes: src.notes, terms: src.terms, lines: lineSet,
    },
  });
  await c.query('UPDATE invoices SET converted_from = $2 WHERE id = $1', [id2, id]);
  await c.query('UPDATE invoices SET converted_to = $2, updated_at = now() WHERE id = $1', [id, id2]);
  return loadInvoice(c, biz.id, id2);
}

module.exports = { CONVERTIBLE, convertToInvoice };
