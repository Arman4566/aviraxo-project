const router = require('express').Router();
const { z } = require('zod');
const { query } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { notFound } = require('../utils/errors');
const { parseId } = require('../utils/ids');
const { todayIST } = require('../utils/time');
const rec = require('../services/receivables');

// "To Collect" card: total receivable, overdue, due today / next 7 days, collected this month, days sales outstanding.
router.get('/summary', asyncHandler(async (req, res) => {
  res.json({ as_of: todayIST(), ...(await rec.summary({ query }, req.business.id)) });
}));

// Aging report: not due, 1-30, 31-60, 61-90, 90+ days past due, in total and per customer.
router.get('/aging', asyncHandler(async (req, res) => {
  const a = await rec.aging({ query }, req.business.id);
  res.json({ ...a, as_of: todayIST() });
}));

const listQuery = z.object({
  sort: z.enum(['overdue', 'amount', 'oldest', 'name', 'risk']).default('overdue'),
  bucket: z.enum(rec.BUCKETS).optional(),
});
// Customers who owe money, with last reminder, open promise, credit-limit flag and payment-risk label.
router.get('/parties', validate(listQuery, 'query'), asyncHandler(async (req, res) => {
  res.json({ as_of: todayIST(), ...(await rec.outstandingParties({ query }, req.business.id, req.query)) });
}));

// Pause or resume automatic reminders for one customer (e.g. a friend, or a dispute being sorted out).
router.put('/parties/:id/reminders', validate(z.object({ paused: z.boolean() })), asyncHandler(async (req, res) => {
  const { rows } = await query(
    'UPDATE parties SET reminders_paused = $3, updated_at = now() WHERE id = $1 AND business_id = $2 RETURNING id, reminders_paused',
    [parseId(req.params.id), req.business.id, req.body.paused]);
  if (!rows[0]) throw notFound('Party not found');
  res.json(rows[0]);
}));

module.exports = router;
