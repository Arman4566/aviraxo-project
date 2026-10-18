const router = require('express').Router();
const { z } = require('zod');
const { query, withTransaction } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { parseId } = require('../utils/ids');
const { audit } = require('../utils/audit');
const { INVITABLE, PERMISSIONS } = require('../utils/permissions');
const svc = require('../services/staff');

const role = z.enum(INVITABLE);
router.get('/', asyncHandler(async (req, res) => res.json({ ...(await svc.listStaff({ query }, req.business.id)), roles: INVITABLE, permissions: PERMISSIONS })));

router.post('/invite', validate(z.object({ email: z.string().trim().max(120), role })), asyncHandler(async (req, res) => {
  const invite = await withTransaction(async (c) => {
    const i = await svc.invite(c, { businessId: req.business.id, userId: req.user.id, email: req.body.email, role: req.body.role });
    await audit(c, { businessId: req.business.id, userId: req.user.id, entity: 'staff', entityId: i.id, action: 'invite', details: { role: i.role } });
    return i;
  });
  res.status(201).json({ invite });
}));
router.delete('/invites/:id', asyncHandler(async (req, res) => {
  await withTransaction((c) => svc.revokeInvite(c, req.business.id, parseId(req.params.id)));
  res.status(204).end();
}));
router.put('/:id', validate(z.object({ role })), asyncHandler(async (req, res) => {
  res.json({ member: await withTransaction((c) => svc.changeRole(c, req.business.id, parseId(req.params.id), req.body.role)) });
}));
router.delete('/:id', asyncHandler(async (req, res) => {
  await withTransaction((c) => svc.removeMember(c, req.business.id, parseId(req.params.id)));
  res.status(204).end();
}));

// Who did what (owner only).
router.get('/audit/log', validate(z.object({ limit: z.coerce.number().int().min(1).max(500).default(100) }), 'query'), asyncHandler(async (req, res) => {
  const { rows } = await query(
    `SELECT a.id, a.entity, a.entity_id, a.action, a.details, a.created_at, u.name AS user_name, u.email AS user_email
       FROM audit_logs a LEFT JOIN users u ON u.id = a.user_id WHERE a.business_id = $1 ORDER BY a.created_at DESC, a.id DESC LIMIT $2`, [req.business.id, req.query.limit]);
  res.json({ log: rows });
}));

module.exports = router;
