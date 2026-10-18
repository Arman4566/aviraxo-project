const router = require('express').Router();
const { z } = require('zod');
const { query, withTransaction } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { forbidden } = require('../utils/errors');
const { todayIST } = require('../utils/time');
const { can } = require('../utils/permissions');
const svc = require('../services/backup');

// Download everything as one JSON file. Keep it somewhere safe (Drive, email to yourself).
router.get('/export', asyncHandler(async (req, res) => {
  const data = await svc.exportAll({ query }, req.business);
  res.setHeader('Content-Disposition', `attachment; filename="galla-pro-backup-${todayIST()}.json"`);
  res.json(data);
}));

// Restore a backup file into an EMPTY firm (create a new firm first). Owner only.
router.post('/restore', asyncHandler(async (req, res) => {
  if (!can(req.business.role, 'backup.restore')) throw forbidden('Only the owner can restore a backup');
  const out = await withTransaction((c) => svc.restore(c, { biz: req.business, userId: req.user.id, data: req.body }));
  res.json(out);
}));

module.exports = router;
