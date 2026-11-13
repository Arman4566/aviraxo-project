const router = require('express').Router();
const { z } = require('zod');
const { query } = require('../db');
const config = require('../config');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { AppError } = require('../utils/errors');
const { can } = require('../utils/permissions');
const gemini = require('../services/gemini');
const ai = require('../services/ai');

// Simple per-business hourly cap so one shop cannot burn the whole free quota. (In memory: resets on restart.)
const usage = new Map();
function limit(req, _res, next) {
  const hour = Math.floor(Date.now() / 3600000);
  const k = `${req.business.id}:${hour}`;
  const n = (usage.get(k) || 0) + 1;
  usage.set(k, n);
  if (usage.size > 5000) for (const key of usage.keys()) if (!key.endsWith(`:${hour}`)) usage.delete(key);
  if (n > config.aiHourlyLimit) return next(new AppError(429, 'AI limit for this hour reached. Please try again later.'));
  next();
}

router.get('/status', (_req, res) => res.json({ enabled: gemini.isConfigured(), model: gemini.isConfigured() ? config.geminiModel : null }));

router.post('/ask', limit, validate(z.object({
  question: z.string().trim().min(2).max(500),
  history: z.array(z.object({ role: z.enum(['user', 'assistant']), text: z.string().max(1500) })).max(10).default([]),
})), asyncHandler(async (req, res) => {
  res.json(await ai.ask({ query }, { business: req.business, role: req.business.role, question: req.body.question, history: req.body.history }));
}));

router.get('/summary', limit, asyncHandler(async (req, res) => {
  res.json(await ai.weeklySummary({ query }, { business: req.business, role: req.business.role }));
}));

router.post('/reminder-draft', limit, validate(z.object({
  party_id: z.number().int().positive(), tone: z.enum(['friendly', 'firm', 'final']).nullable().optional(),
  language: z.enum(['en', 'hi']).default('en'), hint: z.string().max(200).optional(),
})), asyncHandler(async (req, res) => {
  if (!can(req.business.role, 'reminders.manage')) throw new AppError(403, 'Not allowed to send reminders');
  res.json(await ai.draftReminder({ query }, { business: req.business, partyId: req.body.party_id, tone: req.body.tone || null, language: req.body.language, hint: req.body.hint }));
}));

// Photo of a bill -> item list. Needs permission to manage items because the result is meant to create them. Images up to ~5 MB.
router.post('/scan-bill', limit, validate(z.object({
  image_base64: z.string().min(100).max(7_000_000), mime_type: z.enum(['image/jpeg', 'image/png', 'image/webp']).default('image/jpeg'),
})), asyncHandler(async (req, res) => {
  if (!can(req.business.role, 'items.manage')) throw new AppError(403, 'Not allowed to add items');
  const scan = await ai.scanBill({ imageBase64: req.body.image_base64.replace(/^data:[^,]+,/, ''), mimeType: req.body.mime_type });
  res.json({ ...scan, items: await ai.matchExisting({ query }, req.business.id, scan.items) });
}));

// A PDF, Excel (.xlsx) or CSV file of purchases or a price list -> the same checked item list as a photo scan.
router.post('/import-file', limit, validate(z.object({
  file_base64: z.string().min(20).max(9_000_000), file_name: z.string().max(200).default(''),
  mime_type: z.string().max(120).default(''),
})), asyncHandler(async (req, res) => {
  if (!can(req.business.role, 'items.manage')) throw new AppError(403, 'Not allowed to add items');
  const name = req.body.file_name.toLowerCase();
  if (!/\.(pdf|xlsx|csv)$/.test(name) && req.body.mime_type !== 'application/pdf') throw new AppError(400, 'Use a PDF, .xlsx or .csv file');
  const scan = await ai.importFile({ fileBase64: req.body.file_base64.replace(/^data:[^,]+,/, ''), fileName: req.body.file_name, mimeType: req.body.mime_type });
  res.json({ ...scan, items: await ai.matchExisting({ query }, req.business.id, scan.items) });
}));

module.exports = router;
