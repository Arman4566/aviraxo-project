const router = require('express').Router();
const { query, withTransaction } = require('../db');
const asyncHandler = require('../utils/asyncHandler');
const { businessJson } = require('./business');
const { acceptInvitesFor } = require('../services/staff');
const { PERMISSIONS } = require('../utils/permissions');

// Called right after login: who am I, which firms can I use, and what may I do in each?
// Staff invitations sent to this email are accepted here, so an invited cashier lands straight in the shop.
router.get('/', asyncHandler(async (req, res) => {
  const { rows: u } = await query('SELECT id, email, name FROM users WHERE id = $1', [req.user.id]);
  await withTransaction((c) => acceptInvitesFor(c, { userId: req.user.id, email: u[0] && u[0].email }));
  const { rows: b } = await query(
    `SELECT b.*, bu.role FROM businesses b JOIN business_users bu ON bu.business_id = b.id
      WHERE bu.user_id = $1 AND bu.status = 'active' ORDER BY b.created_at`, [req.user.id]);
  const want = String(req.headers['x-business-id'] || '');
  const current = b.find((x) => x.id === want) || b[0];
  const firms = b.map((x) => ({ ...businessJson(x), role: x.role }));
  res.json({
    user: u[0],
    business: current ? { ...businessJson(current), role: current.role } : null,
    businesses: firms,
    permissions: current ? PERMISSIONS[current.role] || [] : [],
  });
}));

module.exports = router;
