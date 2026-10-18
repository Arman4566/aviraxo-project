const router = require('express').Router();
const { z } = require('zod');
const { query, withTransaction } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { parseId } = require('../utils/ids');
const { audit } = require('../utils/audit');
const rem = require('../services/reminders');

const ruleSchema = z.object({
  name: z.string().trim().min(1).max(80),
  trigger_type: z.enum(['before_due', 'on_due', 'after_due']),
  offset_days: z.number().int().min(0).max(365).default(0),
  repeat_every_days: z.number().int().min(1).max(90).nullable().optional(),
  channel: z.enum(['whatsapp', 'sms', 'email']).default('whatsapp'),
  tone: z.enum(['friendly', 'firm', 'final']).default('friendly'),
  template: z.string().max(600).default(''),
  language: z.enum(['en', 'hi']).default('en'),
  is_active: z.boolean().default(true),
});

// Rules: when to nudge, relative to the due date. Three sensible defaults are created the first time.
router.get('/rules', asyncHandler(async (req, res) => {
  await withTransaction((c) => rem.ensureDefaultRules(c, req.business.id));
  res.json({ rules: await rem.listRules({ query }, req.business.id) });
}));
router.post('/rules', validate(ruleSchema), asyncHandler(async (req, res) => {
  const rule = await withTransaction(async (c) => {
    const r = await rem.createRule(c, req.business.id, req.body);
    await audit(c, { businessId: req.business.id, userId: req.user.id, entity: 'reminder_rule', entityId: r.id, action: 'create' });
    return r;
  });
  res.status(201).json({ rule });
}));
router.put('/rules/:id', validate(ruleSchema.partial()), asyncHandler(async (req, res) => {
  const rule = await withTransaction((c) => rem.updateRule(c, req.business.id, parseId(req.params.id), req.body));
  res.json({ rule });
}));
router.delete('/rules/:id', asyncHandler(async (req, res) => {
  await withTransaction((c) => rem.deleteRule(c, req.business.id, parseId(req.params.id)));
  res.status(204).end();
}));

// "Reminders to send today": one ready-to-send message per customer, with WhatsApp / SMS / email links and a UPI link.
router.get('/due', asyncHandler(async (req, res) => {
  const reminders = await withTransaction((c) => rem.dueToday(c, { business: req.business }));
  res.json({ count: reminders.length, reminders });
}));

const composeSchema = z.object({
  party_id: z.number().int().positive(),
  invoice_ids: z.array(z.number().int().positive()).max(100).optional(),
  tone: z.enum(['friendly', 'firm', 'final']).optional(),
  language: z.enum(['en', 'hi']).default('en'),
  template: z.string().max(600).default(''),
});
// The "Remind" button on a customer: builds the message for exactly what the owner selected.
router.post('/compose', validate(composeSchema), asyncHandler(async (req, res) => {
  const b = req.body;
  res.json(await rem.compose({ query }, { business: req.business, partyId: b.party_id, invoiceIds: b.invoice_ids, tone: b.tone, language: b.language, template: b.template }));
}));

const logSchema = z.object({
  party_id: z.number().int().positive(),
  channel: z.enum(['whatsapp', 'sms', 'email']),
  status: z.enum(['sent', 'skipped']).default('sent'),
  message: z.string().max(2000).default(''),
  total_due: z.number().int().min(0).default(0),
  items: z.array(z.object({ invoice_id: z.number().int().positive().nullable(), rule_id: z.number().int().positive().nullable().optional() })).max(200).default([]),
});
// Call this when the owner taps send (or "skip today").
router.post('/log', validate(logSchema), asyncHandler(async (req, res) => {
  const b = req.body;
  const out = await withTransaction((c) => rem.logReminder(c, {
    businessId: req.business.id, userId: req.user.id, partyId: b.party_id, channel: b.channel, status: b.status,
    message: b.message, items: b.items.map((i) => ({ invoice_id: i.invoice_id, rule_id: i.rule_id || null })), totalDue: b.total_due }));
  res.status(201).json(out);
}));

router.get('/log', validate(z.object({ party_id: z.coerce.number().int().positive().optional(), limit: z.coerce.number().int().min(1).max(500).default(100) }), 'query'),
  asyncHandler(async (req, res) => {
    res.json({ log: await rem.listLog({ query }, req.business.id, { partyId: req.query.party_id, limit: req.query.limit }) });
  }));

module.exports = router;
