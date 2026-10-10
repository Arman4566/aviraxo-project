const router = require('express').Router();
const { z } = require('zod');
const { query, withTransaction } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { parseId } = require('../utils/ids');
const { DOC_TYPES, nextNumber, createInvoice, loadInvoice, cancelInvoice } = require('../services/invoices');

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD').refine((s) => !Number.isNaN(Date.parse(`${s}T00:00:00Z`)), 'Not a real date');

const lineSchema = z.object({
  item_id: z.number().int().positive().nullable().optional(),
  name: z.string().trim().min(1).max(300),
  unit: z.string().trim().max(20).default('pcs'),
  hsn: z.string().trim().max(10).default(''),
  gst_slab: z.number().min(0).max(100).default(0),
  qty: z.number().positive().max(1e7),
  rate: z.number().int().min(0),                              // paise
  discount_is_percent: z.boolean().default(true),
  discount_value: z.number().min(0).default(0),              // percent, or paise when flat
  tax_inclusive: z.boolean().default(false),
});
const createSchema = z.object({
  doc_type: z.enum(DOC_TYPES),
  party_id: z.number().int().positive().nullable().optional(),
  cash_customer: z.boolean().default(false),
  invoice_date: isoDate.optional(),
  due_date: isoDate.nullable().optional(),
  payment_method: z.string().trim().max(40).default('Cash'),
  paid_amount: z.number().int().min(0).optional(),           // default: full amount, or nothing for Credit
  gst_enabled: z.boolean().default(false),
  notes: z.string().max(1000).default(''),
  terms: z.string().max(2000).default(''),
  lines: z.array(lineSchema).min(1, 'Add at least one item').max(200),
});

// What the next document number will be (for the preview screen). The saved number is assigned by the server.
router.get('/next-number', asyncHandler(async (req, res) => {
  const docType = DOC_TYPES.includes(req.query.doc_type) ? req.query.doc_type : 'gstInvoice';
  res.json({ invoice_no: await nextNumber({ query }, req.business.id, docType, { consume: false }) });
}));

router.post('/', validate(createSchema), asyncHandler(async (req, res) => {
  const id = await withTransaction((c) => createInvoice(c, { biz: req.business, userId: req.user.id, body: req.body }));
  res.status(201).json({ invoice: await loadInvoice({ query }, req.business.id, id) });
}));

const listQuery = z.object({
  status: z.enum(['open', 'unpaid', 'partial', 'paid', 'cancelled', 'overdue']).optional(),
  party_id: z.coerce.number().int().positive().optional(),
  from: isoDate.optional(),
  to: isoDate.optional(),
  limit: z.coerce.number().int().min(1).max(1000).default(500),
  offset: z.coerce.number().int().min(0).default(0),
});

// Summary rows (no line items). Cancelled invoices are only returned when asked for.
router.get('/', validate(listQuery, 'query'), asyncHandler(async (req, res) => {
  const { status, party_id, from, to, limit, offset } = req.query;
  const params = [req.business.id];
  const where = ['i.business_id = $1'];
  if (status === 'overdue') {
    where.push(`i.affects_books AND i.status IN ('unpaid','partial') AND i.due_date < (now() AT TIME ZONE 'Asia/Kolkata')::date`);
  } else if (status) {
    params.push(status); where.push(`i.status = $${params.length}`);
  } else {
    where.push(`i.status <> 'cancelled'`);
  }
  if (party_id) { params.push(party_id); where.push(`i.party_id = $${params.length}`); }
  if (from) { params.push(from); where.push(`i.invoice_date >= $${params.length}`); }
  if (to) { params.push(to); where.push(`i.invoice_date <= $${params.length}`); }
  params.push(limit, offset);
  const { rows } = await query(
    `SELECT i.*, i.grand_total - i.amount_paid AS balance_due FROM invoices i
      WHERE ${where.join(' AND ')} ORDER BY i.invoice_date DESC, i.id DESC
      LIMIT $${params.length - 1} OFFSET $${params.length}`, params);
  res.json({ invoices: rows });
}));

router.get('/:id', asyncHandler(async (req, res) => {
  res.json({ invoice: await loadInvoice({ query }, req.business.id, parseId(req.params.id)) });
}));

router.post('/:id/cancel', validate(z.object({ reason: z.string().trim().min(3).max(300) })), asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  await withTransaction((c) => cancelInvoice(c, { biz: req.business, userId: req.user.id, id, reason: req.body.reason }));
  res.json({ invoice: await loadInvoice({ query }, req.business.id, id) });
}));

module.exports = router;
