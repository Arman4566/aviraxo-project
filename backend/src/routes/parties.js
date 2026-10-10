const router = require('express').Router();
const { z } = require('zod');
const { query, withTransaction } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { notFound } = require('../utils/errors');
const { parseId } = require('../utils/ids');
const { audit } = require('../utils/audit');
const { PARTY_SELECT, partyJson } = require('../services/partyQueries');

const partySchema = z.object({
  name: z.string().trim().min(1).max(150),
  phone: z.string().trim().max(20).default(''),
  email: z.string().trim().max(120).default(''),
  type: z.enum(['customer', 'supplier', 'both']).default('customer'),
  gst_registered: z.boolean().default(false),
  gstin: z.string().trim().toUpperCase().max(20).default(''),
  state: z.string().trim().max(60).default(''),
  billing_address: z.string().max(500).default(''),
  shipping_address: z.string().max(500).default(''),
  opening_balance: z.number().int().min(0).default(0),   // paise, magnitude only
  to_receive: z.boolean().default(true),                  // true = party owes us, false = we owe the party
  credit_limit: z.number().int().min(0).default(0),
  payment_term: z.string().trim().max(40).default('Immediate'),
});
const updateSchema = partySchema.partial();
const COLUMNS = ['name', 'phone', 'email', 'type', 'gst_registered', 'gstin', 'state', 'billing_address', 'shipping_address',
  'credit_limit', 'payment_term'];

const signed = (mag, toReceive) => (toReceive ? mag : -mag);

async function loadParty(client, businessId, id) {
  const { rows } = await client.query(`${PARTY_SELECT} WHERE p.business_id = $1 AND p.id = $2`, [businessId, id]);
  return rows[0] ? partyJson(rows[0]) : null;
}

router.get('/', asyncHandler(async (req, res) => {
  const { rows } = await query(`${PARTY_SELECT} WHERE p.business_id = $1 AND p.is_active ORDER BY p.updated_at DESC, p.id DESC`, [req.business.id]);
  res.json({ parties: rows.map(partyJson) });
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const party = await loadParty({ query }, req.business.id, parseId(req.params.id));
  if (!party) throw notFound('Party not found');
  res.json({ party });
}));

router.post('/', validate(partySchema), asyncHandler(async (req, res) => {
  const b = req.body;
  const party = await withTransaction(async (c) => {
    const { rows } = await c.query(
      `INSERT INTO parties (business_id, name, phone, email, type, gst_registered, gstin, state, billing_address, shipping_address,
                            opening_balance, credit_limit, payment_term)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING id`,
      [req.business.id, b.name, b.phone, b.email, b.type, b.gst_registered, b.gstin, b.state, b.billing_address,
       b.shipping_address, signed(b.opening_balance, b.to_receive), b.credit_limit, b.payment_term]);
    await audit(c, { businessId: req.business.id, userId: req.user.id, entity: 'party', entityId: rows[0].id, action: 'create' });
    return loadParty(c, req.business.id, rows[0].id);
  });
  res.status(201).json({ party });
}));

router.put('/:id', validate(updateSchema), asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const b = req.body;
  const party = await withTransaction(async (c) => {
    const { rows } = await c.query('SELECT opening_balance FROM parties WHERE id=$1 AND business_id=$2 FOR UPDATE', [id, req.business.id]);
    if (!rows[0]) throw notFound('Party not found');

    const fields = COLUMNS.filter((k) => b[k] !== undefined);
    const values = fields.map((f) => b[f]);
    // opening balance + direction travel together; if only one is sent, keep the other from the stored value
    if (b.opening_balance !== undefined || b.to_receive !== undefined) {
      const mag = b.opening_balance ?? Math.abs(rows[0].opening_balance);
      const toReceive = b.to_receive ?? rows[0].opening_balance >= 0;
      fields.push('opening_balance');
      values.push(signed(mag, toReceive));
    }
    if (fields.length) {
      const sets = fields.map((f, i) => `${f} = $${i + 3}`);
      await c.query(`UPDATE parties SET ${sets.join(', ')}, updated_at = now() WHERE id = $1 AND business_id = $2`,
        [id, req.business.id, ...values]);
    }
    await audit(c, { businessId: req.business.id, userId: req.user.id, entity: 'party', entityId: id, action: 'update' });
    return loadParty(c, req.business.id, id);
  });
  res.json({ party });
}));

// A party with invoices or payments stays (hidden) so history keeps its names.
router.delete('/:id', asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const out = await withTransaction(async (c) => {
    const { rows } = await c.query('SELECT id FROM parties WHERE id=$1 AND business_id=$2 FOR UPDATE', [id, req.business.id]);
    if (!rows[0]) throw notFound('Party not found');
    const { rows: used } = await c.query(
      `SELECT 1 FROM invoices WHERE party_id = $1 UNION ALL SELECT 1 FROM payments WHERE party_id = $1 LIMIT 1`, [id]);
    if (used[0]) {
      await c.query('UPDATE parties SET is_active = FALSE, updated_at = now() WHERE id = $1', [id]);
      return { deleted: false, deactivated: true };
    }
    await c.query('DELETE FROM parties WHERE id = $1', [id]);
    return { deleted: true, deactivated: false };
  });
  res.json(out);
}));

// Statement: opening balance, then invoices (debit) and payments (credit) in date order with a running balance.
router.get('/:id/ledger', asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const { rows: p } = await query('SELECT id, name, opening_balance FROM parties WHERE id=$1 AND business_id=$2', [id, req.business.id]);
  if (!p[0]) throw notFound('Party not found');
  const { rows: entries } = await query(
    `SELECT * FROM (
        SELECT invoice_date AS date, created_at, 'invoice' AS type, invoice_no AS ref, grand_total AS debit, 0::bigint AS credit,
               id, status, doc_type AS note
          FROM invoices WHERE business_id = $1 AND party_id = $2 AND affects_books AND status <> 'cancelled'
        UNION ALL
        SELECT payment_date, created_at, 'payment', CASE WHEN reference_no <> '' THEN reference_no ELSE mode END, 0::bigint, amount,
               id, 'received', mode
          FROM payments WHERE business_id = $1 AND party_id = $2 AND direction = 'in'
     ) t ORDER BY date, created_at, id`, [req.business.id, id]);
  let running = p[0].opening_balance;
  const ledger = entries.map((e) => {
    running += e.debit - e.credit;
    return { date: e.date, type: e.type, ref: e.ref, id: e.id, status: e.status, note: e.note, debit: e.debit, credit: e.credit, balance: running };
  });
  res.json({ party: { id: p[0].id, name: p[0].name }, opening_balance: p[0].opening_balance, entries: ledger, closing_balance: running });
}));

module.exports = router;
