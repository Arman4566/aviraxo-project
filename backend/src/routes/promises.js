const router = require('express').Router();
const { z } = require('zod');
const { query, withTransaction } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { parseId } = require('../utils/ids');
const rem = require('../services/reminders');

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD');
const createSchema = z.object({
  party_id: z.number().int().positive(),
  invoice_id: z.number().int().positive().nullable().optional(),
  promised_date: isoDate,
  amount: z.number().int().min(0).default(0),
  note: z.string().max(300).default(''),
});

// "Promise to pay": the customer commits to a date; overdue reminders pause until then.
router.post('/', validate(createSchema), asyncHandler(async (req, res) => {
  const b = req.body;
  const promise = await withTransaction((c) => rem.createPromise(c, {
    businessId: req.business.id, userId: req.user.id, partyId: b.party_id, invoiceId: b.invoice_id, promisedDate: b.promised_date, amount: b.amount, note: b.note }));
  res.status(201).json({ promise });
}));

router.get('/', validate(z.object({ party_id: z.coerce.number().int().positive().optional(), status: z.enum(['open', 'kept', 'broken', 'cancelled']).optional() }), 'query'),
  asyncHandler(async (req, res) => {
    const promises = await withTransaction((c) => rem.listPromises(c, req.business.id, { partyId: req.query.party_id, status: req.query.status }));
    res.json({ promises });
  }));

router.put('/:id', validate(z.object({ status: z.enum(['open', 'kept', 'broken', 'cancelled']).optional(), promised_date: isoDate.optional(), note: z.string().max(300).optional() })),
  asyncHandler(async (req, res) => {
    const b = req.body;
    const promise = await withTransaction((c) => rem.updatePromise(c, req.business.id, parseId(req.params.id), { status: b.status, promisedDate: b.promised_date, note: b.note }));
    res.json({ promise });
  }));

module.exports = router;
