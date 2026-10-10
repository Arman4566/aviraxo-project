// Stock is a ledger (stock_movements). Current stock and the in/out counters are derived from it.
const ITEM_SELECT = `
  SELECT i.*,
         COALESCE(s.stock, 0)     AS stock_qty,
         COALESCE(s.in_total, 0)  AS stock_in_total,
         COALESCE(s.out_total, 0) AS stock_out_total
    FROM items i
    LEFT JOIN (
      SELECT item_id,
             SUM(qty_in - qty_out) AS stock,
             COALESCE(SUM(qty_in)  FILTER (WHERE reason IN ('opening','purchase')), 0) AS in_total,
             COALESCE(SUM(qty_out) FILTER (WHERE reason = 'sale'), 0)
               - COALESCE(SUM(qty_in) FILTER (WHERE reason = 'sale_cancel'), 0)        AS out_total
        FROM stock_movements WHERE business_id = $1 GROUP BY item_id
    ) s ON s.item_id = i.id`;

function itemJson(r) {
  return {
    id: r.id,
    name: r.name,
    sku: r.sku,
    category: r.category,
    unit: r.unit,
    hsn: r.hsn,
    barcode: r.barcode,
    purchase_price: r.purchase_price,
    selling_price: r.selling_price,
    price_inclusive: r.price_inclusive,
    gst_rate: r.gst_rate,
    gst_enabled: r.gst_enabled,
    stock_enabled: r.stock_enabled,
    stock_qty: r.stock_qty,
    low_stock_level: r.low_stock_level,
    location: r.location,
    stock_in_total: r.stock_in_total,
    stock_out_total: r.stock_out_total,
    updated_at: r.updated_at,
  };
}

/** Business setting (from the app's Inventory settings) that decides whether stock may go below zero. */
const allowsNegativeStock = (business) => business?.settings?.allowNegativeStock === true;

module.exports = { ITEM_SELECT, itemJson, allowsNegativeStock };
