const router = require('express').Router();
const { z } = require('zod');
const { query, withTransaction } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { parseId } = require('../utils/ids');
const { audit } = require('../utils/audit');
const svc = require('../services/expenses');

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD');
const schema = z.object({
  kind: z.enum(['expense', 'income']).default('expense'),          // income = other income
  category: z.string().trim().min(1).max(60),
  amount: z.number().int().positive(),                              // paise, total including GST
  gst_amount: z.number().int().min(0).default(0),
  mode: z.string().trim().max(30).default('cash'),
  entry_date: isoDate.optional(),
  party_id: z.number().int().positive().nullable().optional(),
  note: z.string().max(300).default(''),
  receipt_url: z.string().max(500).default(''),
  recurring: z.enum(['weekly', 'monthly', 'yearly']).nullable().optional(),
  client_ref: z.string().trim().min(8).max(64).optional(),
});

router.get('/', validate(z.object({ from: isoDate.optional(), to: isoDate.optional(), kind: z.enum(['expense', 'income']).optional(), category: z.string().max(60).optional(),
  limit: z.coerce.number().int().min(1).max(1000).default(500), offset: z.coerce.number().int().min(0).default(0) }), 'query'), asyncHandler(async (req, res) => {
  await withTransaction((c) => svc.runRecurring(c, req.business.id));       // recurring entries that fell due appear automatically
  res.json({ expenses: await svc.listExpenses({ query }, req.business.id, req.query) });
}));

router.get('/categories', asyncHandler(async (req, res) => res.json({ categories: await svc.categories({ query }, req.business.id) })));
router.get('/summary', validate(z.object({ from: isoDate, to: isoDate }), 'query'), asyncHandler(async (req, res) => {
  res.json(await svc.summary({ query }, req.business.id, req.query));
}));

router.post('/', validate(schema), asyncHandler(async (req, res) => {
  const expense = await withTransaction(async (c) => {
    const e = await svc.createExpense(c, { businessId: req.business.id, userId: req.user.id, body: req.body });
    await audit(c, { businessId: req.business.id, userId: req.user.id, entity: 'expense', entityId: e.id, action: 'create', details: { amount: e.amount, category: e.category } });
    return e;
  });
  res.status(201).json({ expense });
}));
router.put('/:id', validate(schema.omit({ client_ref: true }).partial()), asyncHandler(async (req, res) => {
  res.json({ expense: await withTransaction((c) => svc.updateExpense(c, req.business.id, parseId(req.params.id), req.body)) });
}));
router.delete('/:id', asyncHandler(async (req, res) => {
  await withTransaction(async (c) => {
    await svc.deleteExpense(c, req.business.id, parseId(req.params.id));
    await audit(c, { businessId: req.business.id, userId: req.user.id, entity: 'expense', entityId: parseId(req.params.id), action: 'delete' });
  });
  res.status(204).end();
}));

module.exports = router;
