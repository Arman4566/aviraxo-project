const router = require('express').Router();
const { z } = require('zod');
const { query, withTransaction } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { notFound, badRequest, conflict } = require('../utils/errors');
const { parseId } = require('../utils/ids');
const { audit } = require('../utils/audit');
const { ITEM_SELECT, itemJson, allowsNegativeStock } = require('../services/itemQueries');

const paise = z.number().int().min(0);
const itemSchema = z.object({
  name: z.string().trim().min(1).max(200),
  sku: z.string().trim().max(60).default(''),
  category: z.string().trim().max(60).default(''),
  unit: z.string().trim().min(1).max(20).default('pcs'),
  hsn: z.string().trim().max(10).default(''),
  barcode: z.string().trim().max(60).default(''),
  purchase_price: paise.default(0),
  selling_price: paise.default(0),
  price_inclusive: z.boolean().default(false),
  gst_rate: z.number().min(0).max(100).default(0),
  gst_enabled: z.boolean().default(false),
  stock_enabled: z.boolean().default(true),
  stock_qty: z.number().min(0).default(0),     // opening stock on create; absolute stock when editing
  low_stock_level: z.number().int().min(0).default(0),
  location: z.string().trim().max(100).default(''),
});
const updateSchema = itemSchema.partial();
const COLUMNS = ['name', 'sku', 'category', 'unit', 'hsn', 'barcode', 'purchase_price', 'selling_price', 'price_inclusive',
  'gst_rate', 'gst_enabled', 'stock_enabled', 'low_stock_level', 'location'];

async function loadItem(client, businessId, id) {
  const { rows } = await client.query(`${ITEM_SELECT} WHERE i.business_id = $1 AND i.id = $2`, [businessId, id]);
  return rows[0] ? itemJson(rows[0]) : null;
}
async function currentStock(client, itemId) {
  const { rows } = await client.query('SELECT COALESCE(SUM(qty_in - qty_out),0) AS stock FROM stock_movements WHERE item_id = $1', [itemId]);
  return rows[0].stock;
}

router.get('/', asyncHandler(async (req, res) => {
  const { rows } = await query(`${ITEM_SELECT} WHERE i.business_id = $1 AND i.is_active ORDER BY i.updated_at DESC, i.id DESC`, [req.business.id]);
  res.json({ items: rows.map(itemJson) });
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const item = await loadItem({ query }, req.business.id, parseId(req.params.id));
  if (!item) throw notFound('Item not found');
  res.json({ item });
}));

router.post('/', validate(itemSchema), asyncHandler(async (req, res) => {
  const b = req.body;
  const item = await withTransaction(async (c) => {
    const { rows } = await c.query(
      `INSERT INTO items (business_id, name, sku, category, unit, hsn, barcode, purchase_price, selling_price, price_inclusive,
                          gst_rate, gst_enabled, stock_enabled, low_stock_level, location)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) RETURNING id`,
      [req.business.id, b.name, b.sku, b.category, b.unit, b.hsn, b.barcode, b.purchase_price, b.selling_price,
       b.price_inclusive, b.gst_rate, b.gst_enabled, b.stock_enabled, b.low_stock_level, b.location]);
    const id = rows[0].id;
    if (b.stock_enabled && b.stock_qty > 0) {
      await c.query(
        `INSERT INTO stock_movements (business_id, item_id, qty_in, reason, ref_type, ref_id, created_by)
         VALUES ($1,$2,$3,'opening','item',$2,$4)`, [req.business.id, id, b.stock_qty, req.user.id]);
    }
    await audit(c, { businessId: req.business.id, userId: req.user.id, entity: 'item', entityId: id, action: 'create' });
    return loadItem(c, req.business.id, id);
  });
  res.status(201).json({ item });
}));

router.put('/:id', validate(updateSchema), asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const b = req.body;
  const item = await withTransaction(async (c) => {
    const { rows } = await c.query('SELECT id, stock_enabled FROM items WHERE id=$1 AND business_id=$2 FOR UPDATE', [id, req.business.id]);
    if (!rows[0]) throw notFound('Item not found');

    const fields = COLUMNS.filter((k) => b[k] !== undefined);
    if (fields.length) {
      const sets = fields.map((f, i) => `${f} = $${i + 3}`);
      await c.query(`UPDATE items SET ${sets.join(', ')}, updated_at = now() WHERE id = $1 AND business_id = $2`,
        [id, req.business.id, ...fields.map((f) => b[f])]);
    }
    // Editing "stock" on the item form sets the absolute quantity; keep the ledger honest with an adjustment row.
    const stockEnabled = b.stock_enabled ?? rows[0].stock_enabled;
    if (stockEnabled && b.stock_qty !== undefined) {
      const diff = b.stock_qty - (await currentStock(c, id));
      if (diff !== 0) {
        await c.query(
          `INSERT INTO stock_movements (business_id, item_id, qty_in, qty_out, reason, ref_type, ref_id, note, created_by)
           VALUES ($1,$2,$3,$4,'adjustment','item',$2,'Edited on item screen',$5)`,
          [req.business.id, id, Math.max(diff, 0), Math.max(-diff, 0), req.user.id]);
        await c.query('UPDATE items SET updated_at = now() WHERE id = $1', [id]);
      }
    }
    await audit(c, { businessId: req.business.id, userId: req.user.id, entity: 'item', entityId: id, action: 'update' });
    return loadItem(c, req.business.id, id);
  });
  res.json({ item });
}));

// Deleting an item that old invoices refer to would break those invoices, so it is hidden instead of removed.
router.delete('/:id', asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const out = await withTransaction(async (c) => {
    const { rows } = await c.query('SELECT id FROM items WHERE id=$1 AND business_id=$2 FOR UPDATE', [id, req.business.id]);
    if (!rows[0]) throw notFound('Item not found');
    const { rows: used } = await c.query('SELECT 1 FROM invoice_lines WHERE item_id = $1 LIMIT 1', [id]);
    if (used[0]) {
      await c.query('UPDATE items SET is_active = FALSE, updated_at = now() WHERE id = $1', [id]);
      return { deleted: false, deactivated: true };
    }
    await c.query('DELETE FROM items WHERE id = $1', [id]);
    return { deleted: true, deactivated: false };
  });
  res.json(out);
}));

// Stock received from a supplier (the app's "Purchase entry"); also refreshes the prices.
const purchaseSchema = z.object({
  qty: z.number().positive().max(1e7),
  purchase_price: paise.nullable().optional(),
  selling_price: paise.nullable().optional(),
});
router.post('/:id/purchase-entry', validate(purchaseSchema), asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const b = req.body;
  const item = await withTransaction(async (c) => {
    const { rows } = await c.query('SELECT stock_enabled FROM items WHERE id=$1 AND business_id=$2 FOR UPDATE', [id, req.business.id]);
    if (!rows[0]) throw notFound('Item not found');
    if (!rows[0].stock_enabled) throw badRequest('Stock tracking is off for this item');
    await c.query(
      `INSERT INTO stock_movements (business_id, item_id, qty_in, reason, ref_type, ref_id, created_by)
       VALUES ($1,$2,$3,'purchase','item',$2,$4)`, [req.business.id, id, b.qty, req.user.id]);
    await c.query(
      `UPDATE items SET purchase_price = COALESCE($3, purchase_price), selling_price = COALESCE($4, selling_price), updated_at = now()
        WHERE id = $1 AND business_id = $2`, [id, req.business.id, b.purchase_price ?? null, b.selling_price ?? null]);
    await audit(c, { businessId: req.business.id, userId: req.user.id, entity: 'item', entityId: id, action: 'purchase_entry', details: { qty: b.qty } });
    return loadItem(c, req.business.id, id);
  });
  res.status(201).json({ item });
}));

const adjustSchema = z.object({
  qty_change: z.number().refine((n) => n !== 0, 'qty_change cannot be 0'),   // +ve adds, -ve removes
  reason: z.string().trim().min(1).max(40).default('correction'),
  note: z.string().max(300).default(''),
});
router.post('/:id/adjust', validate(adjustSchema), asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const { qty_change, reason, note } = req.body;
  const item = await withTransaction(async (c) => {
    const { rows } = await c.query('SELECT stock_enabled FROM items WHERE id=$1 AND business_id=$2 FOR UPDATE', [id, req.business.id]);
    if (!rows[0]) throw notFound('Item not found');
    if (!rows[0].stock_enabled) throw badRequest('Stock tracking is off for this item');
    const after = (await currentStock(c, id)) + qty_change;
    if (after < 0 && !allowsNegativeStock(req.business)) throw conflict(`Adjustment would make stock negative (${after})`);
    await c.query(
      `INSERT INTO stock_movements (business_id, item_id, qty_in, qty_out, reason, ref_type, ref_id, note, created_by)
       VALUES ($1,$2,$3,$4,'adjustment','item',$2,$5,$6)`,
      [req.business.id, id, Math.max(qty_change, 0), Math.max(-qty_change, 0), note ? `${reason}: ${note}` : reason, req.user.id]);
    await c.query('UPDATE items SET updated_at = now() WHERE id = $1', [id]);
    await audit(c, { businessId: req.business.id, userId: req.user.id, entity: 'item', entityId: id, action: 'adjust', details: { qty_change, reason } });
    return loadItem(c, req.business.id, id);
  });
  res.status(201).json({ item });
}));

router.get('/:id/movements', asyncHandler(async (req, res) => {
  const id = parseId(req.params.id);
  const { rows } = await query(
    `SELECT id, qty_in, qty_out, reason, ref_type, ref_id, note, created_at FROM stock_movements
      WHERE business_id = $1 AND item_id = $2 ORDER BY created_at DESC, id DESC LIMIT 200`, [req.business.id, id]);
  res.json({ movements: rows });
}));

module.exports = router;
