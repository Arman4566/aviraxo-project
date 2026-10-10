const router = require('express').Router();
const { query } = require('../db');
const asyncHandler = require('../utils/asyncHandler');
const { TODAY_SQL } = require('../utils/time');
const { ITEM_SELECT } = require('../services/itemQueries');

// One call for the whole home screen.
router.get('/', asyncHandler(async (req, res) => {
  const biz = req.business.id;
  const sold = `business_id = $1 AND affects_books AND status <> 'cancelled'`;
  const [sales, counts, recv, collected, stock, recent] = await Promise.all([
    query(
      `SELECT COALESCE(SUM(grand_total) FILTER (WHERE invoice_date = ${TODAY_SQL}), 0) AS today,
              COALESCE(SUM(grand_total) FILTER (WHERE invoice_date >= date_trunc('week', ${TODAY_SQL})::date), 0) AS this_week,
              COALESCE(SUM(grand_total) FILTER (WHERE invoice_date >= date_trunc('month', ${TODAY_SQL})::date), 0) AS this_month,
              COUNT(*) FILTER (WHERE invoice_date = ${TODAY_SQL}) AS invoices_today
         FROM invoices WHERE ${sold}`, [biz]),
    query(`SELECT COUNT(*) AS total_invoices FROM invoices WHERE business_id = $1 AND status <> 'cancelled'`, [biz]),
    query(
      `SELECT COALESCE(SUM(grand_total - amount_paid), 0) AS receivables,
              COALESCE(SUM(grand_total - amount_paid) FILTER (WHERE due_date < ${TODAY_SQL}), 0) AS overdue_amount,
              COUNT(*) FILTER (WHERE due_date < ${TODAY_SQL}) AS overdue_count
         FROM invoices WHERE business_id = $1 AND affects_books AND status IN ('unpaid','partial')`, [biz]),
    query(`SELECT COALESCE(SUM(amount), 0) AS total FROM payments WHERE business_id = $1 AND direction = 'in' AND payment_date = ${TODAY_SQL}`, [biz]),
    query(
      `SELECT COUNT(*) AS total_items,
              COUNT(*) FILTER (WHERE stock_enabled AND stock_qty > 0) AS in_stock,
              COUNT(*) FILTER (WHERE stock_enabled AND stock_qty > 0 AND stock_qty <= low_stock_level) AS low_stock,
              COUNT(*) FILTER (WHERE stock_enabled AND stock_qty <= 0) AS out_of_stock
         FROM (${ITEM_SELECT} WHERE i.business_id = $1 AND i.is_active) x`, [biz]),
    query(
      `SELECT i.*, i.grand_total - i.amount_paid AS balance_due FROM invoices i
        WHERE i.business_id = $1 AND i.status <> 'cancelled' ORDER BY i.created_at DESC, i.id DESC LIMIT 6`, [biz]),
  ]);
  const n = (v) => Number(v);
  res.json({
    sales: { today: sales.rows[0].today, this_week: sales.rows[0].this_week, this_month: sales.rows[0].this_month, invoices_today: n(sales.rows[0].invoices_today) },
    total_invoices: n(counts.rows[0].total_invoices),
    receivables: { total: recv.rows[0].receivables, overdue_amount: recv.rows[0].overdue_amount, overdue_count: n(recv.rows[0].overdue_count) },
    collected_today: collected.rows[0].total,
    inventory: {
      total_items: n(stock.rows[0].total_items), in_stock: n(stock.rows[0].in_stock),
      low_stock: n(stock.rows[0].low_stock), out_of_stock: n(stock.rows[0].out_of_stock),
    },
    recent_invoices: recent.rows,
  });
}));

module.exports = router;
