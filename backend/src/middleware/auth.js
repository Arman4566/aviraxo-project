const config = require('../config');
const { query } = require('../db');
const { verifyFirebaseIdToken } = require('../utils/firebase');
const { unauthorized, AppError } = require('../utils/errors');
const asyncHandler = require('../utils/asyncHandler');

// firebase uid -> internal user id (avoids a database write on every request)
const userCache = new Map();
const CACHE_MS = 5 * 60 * 1000;

async function provisionUser(claims) {
  const hit = userCache.get(claims.sub);
  if (hit && hit.expires > Date.now()) return hit.id;
  const { rows } = await query(
    `INSERT INTO users (firebase_uid, email, name, last_login_at) VALUES ($1,$2,$3,now())
     ON CONFLICT (firebase_uid) DO UPDATE
        SET email = COALESCE(EXCLUDED.email, users.email),
            name = COALESCE(users.name, EXCLUDED.name),
            last_login_at = now(), updated_at = now()
     RETURNING id`,
    [claims.sub, claims.email || null, claims.name || null]
  );
  userCache.set(claims.sub, { id: rows[0].id, expires: Date.now() + CACHE_MS });
  return rows[0].id;
}

/** Verifies the Firebase ID token and sets req.user = { id, firebaseUid, email }. */
const requireAuth = asyncHandler(async (req, _res, next) => {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7).trim() : '';
  if (!token) throw unauthorized('Missing token');

  let claims;
  if (config.devAuth && token.startsWith('dev:')) {
    const [, name, email] = token.split(':');
    claims = { sub: `dev:${name}`, email: email || null, name };
  } else {
    try {
      claims = await verifyFirebaseIdToken(token, { projectId: config.firebaseProjectId });
    } catch {
      throw unauthorized('Invalid or expired token');
    }
  }
  const id = await provisionUser(claims);
  req.user = { id, firebaseUid: claims.sub, email: claims.email || null };
  next();
});

/**
 * Tenant guard: loads the signed-in user's business into req.business.
 * Every business-owned query MUST filter by req.business.id, so one shop never sees another's data.
 */
const requireBusiness = asyncHandler(async (req, _res, next) => {
  const { rows } = await query(
    `SELECT b.*, bu.role FROM businesses b JOIN business_users bu ON bu.business_id = b.id
      WHERE bu.user_id = $1 AND bu.status = 'active' ORDER BY b.created_at LIMIT 1`,
    [req.user.id]
  );
  if (!rows[0]) throw new AppError(428, 'Business setup required', { code: 'business_setup_required' });
  req.business = rows[0];
  next();
});

module.exports = { requireAuth, requireBusiness };
