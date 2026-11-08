const router = require('express').Router();
const { z } = require('zod');
const { query, withTransaction } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { parseId } = require('../utils/ids');
const { audit } = require('../utils/audit');
const { BOOK_TYPES } = require('../services/invoices');
const { todayIST } = require('../utils/time');
const svc = require('../services/recurring');

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
  discount_value: z.number().min(0).default(0),
  tax_inclusive: z.boolean().default(false),
});
const createSchema = z.object({
  name: z.string().trim().min(1).max(120),
  party_id: z.number().int().positive(),
  frequency: z.enum(svc.FREQUENCIES),
  start_date: isoDate,
  end_date: isoDate.nullable().optional(),
  doc_type: z.enum(BOOK_TYPES).default('gstInvoice'),
  payment_method: z.string().trim().max(40).default('Credit (Pay Later)'),
  due_days: z.number().int().min(0).max(365).default(0),
  gst_enabled: z.boolean().default(false),
  notes: z.string().max(1000).default(''),
  terms: z.string().max(2000).default(''),
  lines: z.array(lineSchema).min(1, 'Add at least one item').max(50),
});

const runner = () => ({ query, tx: withTransaction });

router.get('/', asyncHandler(async (req, res) => {
  res.json({ schedules: await svc.list({ query }, req.business.id) });
}));

router.post('/', validate(createSchema), asyncHandler(async (req, res) => {
  const id = await svc.create({ query }, { biz: req.business, userId: req.user.id, input: req.body });
  await audit({ query }, { businessId: req.business.id, userId: req.user.id, entity: 'recurring_invoice', entityId: id, action: 'create', details: { frequency: req.body.frequency, start: req.body.start_date } });
  res.status(201).json({ schedules: await svc.list({ query }, req.business.id) });
}));

// Creates whatever is due today. The app calls this when it opens; the owner can also tap "Run now".
router.post('/run', asyncHandler(async (req, res) => {
  res.json(await svc.runDue(runner(req), { biz: req.business, userId: req.user.id, today: todayIST() }));
}));

router.post('/:id/pause', asyncHandler(async (req, res) => {
  await svc.setActive({ query }, req.business.id, parseId(req.params.id), false);
  res.json({ schedules: await svc.list({ query }, req.business.id) });
}));

router.post('/:id/resume', asyncHandler(async (req, res) => {
  await svc.setActive({ query }, req.business.id, parseId(req.params.id), true);
  res.json({ schedules: await svc.list({ query }, req.business.id) });
}));

router.delete('/:id', asyncHandler(async (req, res) => {
  await svc.remove({ query }, req.business.id, parseId(req.params.id));
  res.json({ schedules: await svc.list({ query }, req.business.id) });
}));

module.exports = router;
