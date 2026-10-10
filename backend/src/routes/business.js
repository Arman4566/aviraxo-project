const router = require('express').Router();
const { z } = require('zod');
const { query, withTransaction } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { badRequest } = require('../utils/errors');
const { stateCodeFromName } = require('../utils/states');
const { isValidGstin } = require('../utils/invoiceMath');
const { audit } = require('../utils/audit');

// Lenient on purpose: the app's onboarding never blocks on GST details ("you can edit later").
// gstin_valid tells the app whether the GSTIN passes the official checksum.
const schema = z.object({
  name: z.string().trim().min(1).max(150).optional(),
  business_type: z.string().trim().max(40).nullable().optional(),
  industry: z.string().trim().max(60).nullable().optional(),
  gst_registered: z.boolean().optional(),
  gstin: z.string().trim().toUpperCase().max(20).nullable().optional(),
  address: z.string().max(500).nullable().optional(),
  state: z.string().trim().max(60).nullable().optional(),
  pincode: z.string().trim().max(10).nullable().optional(),
  currency: z.string().trim().max(5).optional(),
  settings: z.record(z.any()).optional(),   // onboarding answers + app preferences, stored as-is
});

function businessJson(b) {
  return {
    id: b.id,
    name: b.name,
    business_type: b.business_type,
    industry: b.industry,
    gst_registered: b.gst_registered,
    gstin: b.gstin,
    gstin_valid: b.gstin ? isValidGstin(b.gstin) : null,
    address: b.address,
    state: b.state,
    state_code: b.state_code,
    pincode: b.pincode,
    currency: b.currency,
    settings: b.settings || {},
    updated_at: b.updated_at,
  };
}

/** GSTIN (when valid) decides the state; otherwise the state name does. */
function deriveStateCode(gstin, state) {
  if (gstin && isValidGstin(gstin)) return gstin.slice(0, 2);
  return stateCodeFromName(state);
}

router.get('/', asyncHandler(async (req, res) => {
  res.json({ business: businessJson(req.business) });
}));

// Create-or-update the signed-in user's business. Partial updates are fine (e.g. only `settings`).
router.put('/', validate(schema), asyncHandler(async (req, res) => {
  const b = req.body;
  const business = await withTransaction(async (c) => {
    const { rows: existing } = await c.query(
      `SELECT b.* FROM businesses b JOIN business_users bu ON bu.business_id = b.id
        WHERE bu.user_id = $1 AND bu.status = 'active' ORDER BY b.created_at LIMIT 1 FOR UPDATE OF b`, [req.user.id]);
    const cur = existing[0];
    if (!cur && !b.name) throw badRequest('name is required to set up a business');

    const m = (k, d = null) => (b[k] !== undefined ? b[k] : cur ? cur[k] : d);
    const gstin = m('gstin');
    const state = m('state');
    const gstRegistered = m('gst_registered', false);
    const values = [
      m('name'), m('business_type'), m('industry'), gstRegistered, gstin || null, m('address'), state,
      deriveStateCode(gstin, state), m('pincode'), m('currency', 'INR') || 'INR',
      JSON.stringify(b.settings !== undefined ? b.settings : cur ? cur.settings : {}),
    ];

    if (cur) {
      const { rows } = await c.query(
        `UPDATE businesses SET name=$2, business_type=$3, industry=$4, gst_registered=$5, gstin=$6, address=$7, state=$8,
                state_code=$9, pincode=$10, currency=$11, settings=$12::jsonb, updated_at=now()
          WHERE id=$1 RETURNING *`, [cur.id, ...values]);
      return rows[0];
    }
    const { rows } = await c.query(
      `INSERT INTO businesses (owner_user_id, name, business_type, industry, gst_registered, gstin, address, state,
                               state_code, pincode, currency, settings)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::jsonb) RETURNING *`, [req.user.id, ...values]);
    await c.query(`INSERT INTO business_users (business_id, user_id, role) VALUES ($1,$2,'owner')`, [rows[0].id, req.user.id]);
    await audit(c, { businessId: rows[0].id, userId: req.user.id, entity: 'business', entityId: null, action: 'create' });
    return rows[0];
  });
  res.json({ business: businessJson(business) });
}));

module.exports = router;
module.exports.businessJson = businessJson;
