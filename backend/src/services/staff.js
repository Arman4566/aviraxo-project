// Staff invitations and roles. Every function takes a db client (see receivables.js).
const { notFound, badRequest, conflict } = require('../utils/errors');
const { INVITABLE } = require('../utils/permissions');

async function listStaff(db, businessId) {
  const { rows: members } = await db.query(
    `SELECT bu.id, bu.user_id, u.email, u.name, bu.role, bu.status, bu.created_at, u.last_login_at
       FROM business_users bu JOIN users u ON u.id = bu.user_id WHERE bu.business_id = $1 AND bu.status = 'active' ORDER BY bu.role = 'owner' DESC, bu.created_at`, [businessId]);
  const { rows: invites } = await db.query(
    `SELECT id, email, role, status, created_at FROM staff_invites WHERE business_id = $1 AND status = 'pending' ORDER BY created_at DESC`, [businessId]);
  return { members, invites };
}

/** Invite by email. When that person signs in with this email they join automatically. */
async function invite(db, { businessId, userId, email, role }) {
  if (!INVITABLE.includes(role)) throw badRequest(`Role must be one of: ${INVITABLE.join(', ')}`);
  const clean = String(email || '').trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(clean)) throw badRequest('Enter a valid email address');
  const { rows: [existing] } = await db.query(
    `SELECT bu.id FROM business_users bu JOIN users u ON u.id = bu.user_id WHERE bu.business_id = $1 AND bu.status = 'active' AND lower(u.email) = $2`, [businessId, clean]);
  if (existing) throw conflict('This person is already part of your team');
  await db.query(`UPDATE staff_invites SET status = 'revoked' WHERE business_id = $1 AND lower(email) = $2 AND status = 'pending'`, [businessId, clean]);
  const { rows } = await db.query(`INSERT INTO staff_invites (business_id, email, role, invited_by) VALUES ($1,$2,$3,$4) RETURNING *`, [businessId, clean, role, userId]);
  return rows[0];
}

async function revokeInvite(db, businessId, id) {
  const { rows } = await db.query(`UPDATE staff_invites SET status = 'revoked' WHERE id = $1 AND business_id = $2 AND status = 'pending' RETURNING id`, [id, businessId]);
  if (!rows[0]) throw notFound('Invite not found');
}

/** Called when a signed-in user has no business (or on /me): joins every pending invite sent to their email. */
async function acceptInvitesFor(db, { userId, email }) {
  if (!email) return [];
  const { rows } = await db.query(`SELECT * FROM staff_invites WHERE status = 'pending' AND lower(email) = $1 ORDER BY id FOR UPDATE`, [String(email).toLowerCase()]);
  for (const inv of rows) {
    await db.query(
      `INSERT INTO business_users (business_id, user_id, role) VALUES ($1,$2,$3)
       ON CONFLICT (business_id, user_id) DO UPDATE SET role = EXCLUDED.role, status = 'active'`, [inv.business_id, userId, inv.role]);
    await db.query(`UPDATE staff_invites SET status = 'accepted' WHERE id = $1`, [inv.id]);
  }
  return rows.map((r) => r.business_id);
}

async function changeRole(db, businessId, memberId, role) {
  if (!INVITABLE.includes(role)) throw badRequest(`Role must be one of: ${INVITABLE.join(', ')}`);
  const { rows: [m] } = await db.query('SELECT * FROM business_users WHERE id = $1 AND business_id = $2 FOR UPDATE', [memberId, businessId]);
  if (!m) throw notFound('Team member not found');
  if (m.role === 'owner') throw conflict('The owner\'s role cannot be changed');
  const { rows } = await db.query('UPDATE business_users SET role = $3 WHERE id = $1 AND business_id = $2 RETURNING *', [memberId, businessId, role]);
  return rows[0];
}

async function removeMember(db, businessId, memberId) {
  const { rows: [m] } = await db.query('SELECT * FROM business_users WHERE id = $1 AND business_id = $2 FOR UPDATE', [memberId, businessId]);
  if (!m) throw notFound('Team member not found');
  if (m.role === 'owner') throw conflict('The owner cannot be removed');
  await db.query(`UPDATE business_users SET status = 'inactive' WHERE id = $1`, [memberId]);
}

module.exports = { listStaff, invite, revokeInvite, acceptInvitesFor, changeRole, removeMember };
