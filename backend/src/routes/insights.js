const router = require('express').Router();
const { z } = require('zod');
const { query } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { parseId } = require('../utils/ids');
const { isValidGstin } = require('../utils/invoiceMath');
const svc = require('../services/insights');

router.get('/summary', asyncHandler(async (req, res) => res.json(await svc.businessInsights({ query }, req.business.id))));
router.get('/forecast', validate(z.object({ days: z.coerce.number().int().min(7).max(90).default(28) }), 'query'), asyncHandler(async (req, res) => {
  res.json(await svc.cashForecast({ query }, req.business.id, { days: req.query.days }));
}));
router.get('/risk/:partyId', asyncHandler(async (req, res) => res.json(await svc.partyRisk({ query }, req.business.id, parseId(req.params.partyId)))));

// Run before saving an invoice: duplicate bill, bad GSTIN, missing HSN, price below cost, tax-rate mismatch.
const line = z.object({ item_id: z.number().int().positive().nullable().optional(), name: z.string().max(300), rate: z.number().int().min(0),
  gst_slab: z.number().min(0).max(100).default(0), hsn: z.string().max(10).default(''), tax_inclusive: z.boolean().default(false) });
router.post('/check-invoice', validate(z.object({ party_id: z.number().int().positive().nullable().optional(), total: z.number().int().min(0).default(0),
  gst_enabled: z.boolean().default(false), lines: z.array(line).max(200) })), asyncHandler(async (req, res) => {
  res.json(await svc.checkInvoiceDraft({ query }, req.business, req.body));
}));

// Instant GSTIN check for the party form (format + checksum + state).
router.get('/gstin/:gstin', asyncHandler(async (req, res) => {
  const g = String(req.params.gstin || '').trim().toUpperCase();
  const valid = isValidGstin(g);
  res.json({ gstin: g, valid, state_code: valid ? g.slice(0, 2) : null, pan: valid ? g.slice(2, 12) : null });
}));

module.exports = router;
