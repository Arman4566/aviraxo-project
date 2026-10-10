const router = require('express').Router();
const { query } = require('../db');
const asyncHandler = require('../utils/asyncHandler');
const { businessJson } = require('./business');

// Called right after login: who am I, and do I already have a business (so the app can skip onboarding)?
router.get('/', asyncHandler(async (req, res) => {
  const { rows: u } = await query('SELECT id, email, name FROM users WHERE id = $1', [req.user.id]);
  const { rows: b } = await query(
    `SELECT b.* FROM businesses b JOIN business_users bu ON bu.business_id = b.id
      WHERE bu.user_id = $1 AND bu.status = 'active' ORDER BY b.created_at LIMIT 1`, [req.user.id]);
  res.json({ user: u[0], business: b[0] ? businessJson(b[0]) : null });
}));

module.exports = router;
