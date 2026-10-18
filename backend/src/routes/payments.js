const router = require('express').Router();
const { z } = require('zod');
const { query, withTransaction } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { notFound } = require('../utils/errors');
const { recordPayment } = require('../services/payments');
const { normalizeMode } = require('../utils/payments');
const { todayIST } = require('../utils/time');
const { audit } = require('../utils/audit');

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const schema = z.object({
  party_id: z.number().int().positive(),
  amount: z.number().int().positive(),
  mode: z.string().trim().min(1).max(30).default('cash'),
  payment_date: isoDate.optional(),
  reference_no: z.string().max(60).default(''),
  notes: z.string().max(300).default(''),
  client_ref: z.string().trim().min(8).max(64).optional(),
  allocations: z.array(z.object({ invoice_id: z.number().int().positive(), amount: z.number().int().positive() })).max(100).optional(),
});

// Payment received from a party. Without allocations it settles their oldest open invoices first.
router.post('/', validate(schema), asyncHandler(async (req, res) => {
  const b = req.body;
  const out = await withTransaction(async (c) => {
    const { rows } = await c.query('SELECT id FROM parties WHERE id=$1 AND business_id=$2 FOR UPDATE', [b.party_id, req.business.id]);
    if (!rows[0]) throw notFound('Party not found');
    const r = await recordPayment(c, {
      businessId: req.business.id, userId: req.user.id, partyId: b.party_id, amount: b.amount, mode: normalizeMode(b.mode),
      paymentDate: b.payment_date || todayIST(), referenceNo: b.reference_no, notes: b.notes, allocations: b.allocations, clientRef: b.client_ref,
    });
    if (!r.duplicate) await audit(c, { businessId: req.business.id, userId: req.user.id, entity: 'payment', entityId: r.payment.id, action: 'create', details: { amount: b.amount } });
    return r;
  });
  res.status(out.duplicate ? 200 : 201).json(out);
}));

const listQuery = z.object({
  party_id: z.coerce.number().int().positive().optional(),
  from: isoDate.optional(),
  to: isoDate.optional(),
  limit: z.coerce.number().int().min(1).max(1000).default(200),
  offset: z.coerce.number().int().min(0).default(0),
});
router.get('/', validate(listQuery, 'query'), asyncHandler(async (req, res) => {
  const { party_id, from, to, limit, offset } = req.query;
  const params = [req.business.id];
  const where = ['p.business_id = $1', `p.direction = 'in'`];
  if (party_id) { params.push(party_id); where.push(`p.party_id = $${params.length}`); }
  if (from) { params.push(from); where.push(`p.payment_date >= $${params.length}`); }
  if (to) { params.push(to); where.push(`p.payment_date <= $${params.length}`); }
  params.push(limit, offset);
  const { rows } = await query(
    `SELECT p.id, p.party_id, p.payment_date, p.amount, p.mode, p.reference_no, p.notes, pt.name AS party_name,
            COALESCE((SELECT SUM(amount) FROM payment_allocations WHERE payment_id = p.id), 0) AS allocated
       FROM payments p LEFT JOIN parties pt ON pt.id = p.party_id
      WHERE ${where.join(' AND ')} ORDER BY p.payment_date DESC, p.id DESC
      LIMIT $${params.length - 1} OFFSET $${params.length}`, params);
  res.json({ payments: rows });
}));

module.exports = router;
