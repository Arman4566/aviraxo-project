// Low-stock alerts, reorder suggestions and barcode lookup. Every function takes a db client.
const { ITEM_SELECT, itemJson } = require('./itemQueries');
const { TODAY_SQL } = require('../utils/time');

/**
 * Items at or below their alert level (or out of stock). `sold_30d` is what actually sold in the last 30 days;
 * the suggested reorder brings stock up to cover 30 days of that selling speed, or twice the alert level, whichever is more.
 */
async function lowStock(db, businessId) {
  const { rows } = await db.query(
    `SELECT x.*, COALESCE(s.sold_30d, 0) AS sold_30d FROM (${ITEM_SELECT} WHERE i.business_id = $1 AND i.is_active AND i.stock_enabled) x
       LEFT JOIN (SELECT l.item_id, SUM(l.qty) AS sold_30d FROM invoice_lines l JOIN invoices v ON v.id = l.invoice_id
                   WHERE v.business_id = $1 AND v.affects_books AND v.status <> 'cancelled' AND v.invoice_date >= ${TODAY_SQL} - 30
                   GROUP BY l.item_id) s ON s.item_id = x.id
      WHERE x.stock_qty <= 0 OR (x.low_stock_level > 0 AND x.stock_qty <= x.low_stock_level)
      ORDER BY x.stock_qty <= 0 DESC, x.stock_qty, lower(x.name)`, [businessId]);
  const alerts = rows.map((r) => {
    const perDay = r.sold_30d / 30;
    const target = Math.max(r.low_stock_level * 2, Math.ceil(r.sold_30d));
    return {
      ...itemJson(r),
      status: r.stock_qty <= 0 ? 'out' : 'low',
      sold_30d: r.sold_30d,
      days_of_cover: perDay > 0 ? Math.max(0, Math.floor(r.stock_qty / perDay)) : null,
      suggested_reorder: Math.max(0, Math.ceil(target - Math.max(r.stock_qty, 0))),
    };
  });
  return { out_of_stock: alerts.filter((a) => a.status === 'out').length, low: alerts.filter((a) => a.status === 'low').length, alerts };
}

/** Scanner lookup: exact barcode first, then SKU. */
async function byBarcode(db, businessId, code) {
  const { rows } = await db.query(
    `SELECT * FROM (${ITEM_SELECT} WHERE i.business_id = $1 AND i.is_active) x
      WHERE x.barcode = $2 OR (x.barcode = '' AND x.sku = $2) ORDER BY (x.barcode = $2) DESC LIMIT 1`, [businessId, String(code).trim()]);
  return rows[0] ? itemJson(rows[0]) : null;
}

module.exports = { lowStock, byBarcode };
