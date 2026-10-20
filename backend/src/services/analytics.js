// Numbers behind the analytics dashboard. Every amount is integer paise. Pure SQL + a little merging, no external service.
const { addDays, daysBetween } = require('../utils/format');

const BOOKS = `i.affects_books AND i.status <> 'cancelled'`;
const n = (v) => (v === null || v === undefined ? 0 : Number(v));
const pct = (cur, prev) => (prev > 0 ? Math.round(((cur - prev) / prev) * 1000) / 10 : (cur > 0 ? null : 0));

/** day for up to 45 days, week up to 180, month beyond. Keeps charts readable. */
function granularityFor(days) { return days <= 45 ? 'day' : days <= 180 ? 'week' : 'month'; }

async function totals(db, businessId, from, to) {
  const [{ rows: [s] }, { rows: [p] }, { rows: [e] }, { rows: [c] }] = await Promise.all([
    db.query(
      `SELECT COALESCE(SUM(i.grand_total), 0) AS sales, COUNT(*) AS orders, COALESCE(SUM(i.tax_total), 0) AS tax,
              COALESCE(SUM(i.taxable_value), 0) AS taxable
         FROM invoices i WHERE i.business_id = $1 AND ${BOOKS} AND i.invoice_date BETWEEN $2 AND $3`, [businessId, from, to]),
    db.query(`SELECT COALESCE(SUM(amount), 0) AS collected FROM payments WHERE business_id = $1 AND direction = 'in' AND payment_date BETWEEN $2 AND $3`, [businessId, from, to]),
    db.query(
      `SELECT COALESCE(SUM(amount) FILTER (WHERE kind = 'expense'), 0) AS spent, COALESCE(SUM(amount) FILTER (WHERE kind = 'income'), 0) AS other_income
         FROM expenses WHERE business_id = $1 AND entry_date BETWEEN $2 AND $3`, [businessId, from, to]),
    db.query(
      `SELECT COALESCE(SUM(l.taxable_value - ROUND(l.qty * COALESCE(it.purchase_price, 0))), 0) AS gross_profit,
              COALESCE(SUM(l.taxable_value), 0) AS revenue_ex_tax
         FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id LEFT JOIN items it ON it.id = l.item_id
        WHERE i.business_id = $1 AND ${BOOKS} AND i.invoice_date BETWEEN $2 AND $3`, [businessId, from, to]),
  ]);
  const sales = n(s.sales), orders = n(s.orders), spent = n(e.spent), otherIncome = n(e.other_income);
  const gross = n(c.gross_profit);
  return {
    sales, orders, avg_order: orders ? Math.round(sales / orders) : 0, tax_collected: n(s.tax),
    collected: n(p.collected), expenses: spent, other_income: otherIncome,
    gross_profit: gross, net_profit: gross + otherIncome - spent,
    margin_pct: n(c.revenue_ex_tax) > 0 ? Math.round((gross / n(c.revenue_ex_tax)) * 1000) / 10 : 0,
  };
}

async function overview(db, businessId, { from, to }) {
  const days = daysBetween(from, to) + 1;
  const gran = granularityFor(days);
  const prevTo = addDays(from, -1), prevFrom = addDays(from, -days);

  const [cur, prev, buckets, sales, coll, exp, items, customers, modes, cats, monthly, weekdays] = await Promise.all([
    totals(db, businessId, from, to),
    totals(db, businessId, prevFrom, prevTo),
    db.query(`SELECT to_char(d::date, 'YYYY-MM-DD') AS d FROM generate_series(date_trunc('${gran}', $1::date), $2::date, '1 ${gran}'::interval) d ORDER BY d`, [from, to]),
    db.query(`SELECT to_char(date_trunc('${gran}', i.invoice_date), 'YYYY-MM-DD') AS d, SUM(i.grand_total) AS v FROM invoices i
               WHERE i.business_id = $1 AND ${BOOKS} AND i.invoice_date BETWEEN $2 AND $3 GROUP BY 1`, [businessId, from, to]),
    db.query(`SELECT to_char(date_trunc('${gran}', payment_date), 'YYYY-MM-DD') AS d, SUM(amount) AS v FROM payments
               WHERE business_id = $1 AND direction = 'in' AND payment_date BETWEEN $2 AND $3 GROUP BY 1`, [businessId, from, to]),
    db.query(`SELECT to_char(date_trunc('${gran}', entry_date), 'YYYY-MM-DD') AS d, SUM(amount) AS v FROM expenses
               WHERE business_id = $1 AND kind = 'expense' AND entry_date BETWEEN $2 AND $3 GROUP BY 1`, [businessId, from, to]),
    db.query(`SELECT l.name, SUM(l.qty) AS qty, SUM(l.line_total) AS revenue FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id
               WHERE i.business_id = $1 AND ${BOOKS} AND i.invoice_date BETWEEN $2 AND $3 GROUP BY l.name ORDER BY revenue DESC LIMIT 8`, [businessId, from, to]),
    db.query(`SELECT COALESCE(NULLIF(i.party_name, ''), 'Walk-in customer') AS name, SUM(i.grand_total) AS total, COUNT(*) AS orders FROM invoices i
               WHERE i.business_id = $1 AND ${BOOKS} AND i.invoice_date BETWEEN $2 AND $3 GROUP BY 1 ORDER BY total DESC LIMIT 8`, [businessId, from, to]),
    db.query(`SELECT mode, SUM(amount) AS total FROM payments WHERE business_id = $1 AND direction = 'in' AND payment_date BETWEEN $2 AND $3 GROUP BY mode ORDER BY total DESC`, [businessId, from, to]),
    db.query(`SELECT category, SUM(amount) AS total FROM expenses WHERE business_id = $1 AND kind = 'expense' AND entry_date BETWEEN $2 AND $3 GROUP BY category ORDER BY total DESC LIMIT 8`, [businessId, from, to]),
    db.query(
      `WITH m AS (SELECT to_char(date_trunc('month', d), 'YYYY-MM') AS m FROM generate_series(date_trunc('month', $2::date) - interval '5 months', date_trunc('month', $2::date), '1 month') d)
       SELECT m.m,
              COALESCE((SELECT SUM(i.grand_total) FROM invoices i WHERE i.business_id = $1 AND ${BOOKS} AND to_char(i.invoice_date, 'YYYY-MM') = m.m), 0) AS sales,
              COALESCE((SELECT SUM(e.amount) FROM expenses e WHERE e.business_id = $1 AND e.kind = 'expense' AND to_char(e.entry_date, 'YYYY-MM') = m.m), 0) AS expenses
         FROM m ORDER BY m.m`, [businessId, to]),
    db.query(`SELECT EXTRACT(DOW FROM i.invoice_date)::int AS dow, SUM(i.grand_total) AS total FROM invoices i
               WHERE i.business_id = $1 AND ${BOOKS} AND i.invoice_date BETWEEN $2 AND $3 GROUP BY 1`, [businessId, from, to]),
  ]);

  const toMap = (r) => new Map(r.rows.map((x) => [x.d, n(x.v)]));
  const sM = toMap(sales), cM = toMap(coll), eM = toMap(exp);
  const series = buckets.rows.map(({ d }) => ({ date: d, sales: sM.get(d) || 0, collected: cM.get(d) || 0, expenses: eM.get(d) || 0 }));

  const wd = new Map(weekdays.rows.map((r) => [r.dow, n(r.total)]));
  const dowSales = [0, 1, 2, 3, 4, 5, 6].map((dow) => ({ dow, sales: wd.get(dow) || 0 }));
  const best = dowSales.reduce((a, b) => (b.sales > a.sales ? b : a), dowSales[0]);
  const modeTotal = modes.rows.reduce((s, r) => s + n(r.total), 0);

  return {
    from, to, days, granularity: gran, previous: { from: prevFrom, to: prevTo },
    totals: cur, previous_totals: prev,
    change_pct: {
      sales: pct(cur.sales, prev.sales), collected: pct(cur.collected, prev.collected), expenses: pct(cur.expenses, prev.expenses),
      orders: pct(cur.orders, prev.orders), net_profit: prev.net_profit > 0 ? pct(cur.net_profit, prev.net_profit) : null,
    },
    series,
    top_items: items.rows.map((r) => ({ name: r.name, qty: n(r.qty), revenue: n(r.revenue) })),
    top_customers: customers.rows.map((r) => ({ name: r.name, total: n(r.total), orders: n(r.orders) })),
    payment_modes: modes.rows.map((r) => ({ mode: r.mode, total: n(r.total), share_pct: modeTotal ? Math.round((n(r.total) / modeTotal) * 1000) / 10 : 0 })),
    expense_categories: cats.rows.map((r) => ({ category: r.category, total: n(r.total) })),
    monthly: monthly.rows.map((r) => ({ month: r.m, sales: n(r.sales), expenses: n(r.expenses), profit_estimate: n(r.sales) - n(r.expenses) })),
    weekdays: dowSales,
    best_weekday: best.sales > 0 ? best.dow : null,
  };
}

module.exports = { overview, totals, granularityFor };
