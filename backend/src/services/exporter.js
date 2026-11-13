// Turns report data into a plain table ({title, columns, rows}) so the same report can be sent as CSV, Excel, or JSON (the app builds PDFs from JSON).
// Money is converted from paise to rupees here; nothing else about the numbers changes.
const fin = require('./finance');
const { ITEM_SELECT, itemJson } = require('./itemQueries');
const { toCsv, writeXlsx } = require('../utils/xlsx');

const rs = (p) => Math.round(Number(p || 0)) / 100;
const REPORTS = ['profit-loss', 'sales', 'tax-summary', 'stock', 'receivables'];

async function table(db, business, report, { from, to, group = 'day' }) {
  const id = business.id;
  if (report === 'profit-loss') {
    const p = await fin.profitLoss(db, business, { from, to });
    const rows = [
      ['Sales (before tax)', rs(p.sales)], ['Cost of goods sold', rs(p.cost_of_goods)], ['Gross profit', rs(p.gross_profit)],
      ['Gross margin %', p.gross_margin_pct ?? ''], ...p.expenses_by_category.map((e) => [`Expense: ${e.category || 'Uncategorised'}`, rs(e.total)]),
      ['Total expenses', rs(p.expenses)], ['Other income', rs(p.other_income)], ['Net profit', rs(p.net_profit)], ['GST collected (not income)', rs(p.tax_collected)],
    ];
    return { title: `Profit & Loss ${from} to ${to}`, columns: ['Line', 'Amount (Rs)'], rows };
  }
  if (report === 'sales') {
    const base = `i.business_id = $1 AND i.affects_books AND i.status <> 'cancelled' AND i.invoice_date BETWEEN $2 AND $3`;
    const g = ['day', 'party', 'item'].includes(group) ? group : 'day';
    const sql = g === 'party'
      ? `SELECT COALESCE(NULLIF(i.party_name,''),'Cash Customer') AS label, COUNT(*) AS n, SUM(i.grand_total) AS total FROM invoices i WHERE ${base} GROUP BY 1 ORDER BY total DESC`
      : g === 'item'
        ? `SELECT l.name AS label, SUM(l.qty) AS n, SUM(l.line_total) AS total FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id WHERE ${base} GROUP BY 1 ORDER BY total DESC`
        : `SELECT i.invoice_date::text AS label, COUNT(*) AS n, SUM(i.grand_total) AS total FROM invoices i WHERE ${base} GROUP BY 1 ORDER BY 1`;
    const { rows } = await db.query(sql, [id, from, to]);
    const head = { day: 'Date', party: 'Customer', item: 'Item' }[g];
    const countHead = g === 'item' ? 'Qty sold' : 'Invoices';
    return { title: `Sales by ${g} ${from} to ${to}`, columns: [head, countHead, 'Total (Rs)'], rows: rows.map((r) => [r.label, Number(r.n), rs(r.total)]) };
  }
  if (report === 'tax-summary') {
    const { rows } = await db.query(
      `SELECT l.gst_slab AS rate, SUM(l.taxable_value) AS taxable, SUM(l.cgst) AS cgst, SUM(l.sgst) AS sgst, SUM(l.igst) AS igst
         FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id
        WHERE i.business_id = $1 AND i.affects_books AND i.gst_enabled AND i.status <> 'cancelled' AND i.invoice_date BETWEEN $2 AND $3
        GROUP BY l.gst_slab ORDER BY l.gst_slab`, [id, from, to]);
    const out = rows.map((r) => [`${Number(r.rate)}%`, rs(r.taxable), rs(r.cgst), rs(r.sgst), rs(r.igst), rs(Number(r.cgst) + Number(r.sgst) + Number(r.igst))]);
    const tot = out.reduce((a, r) => a.map((v, i) => (i === 0 ? 'Total' : Math.round((v + r[i]) * 100) / 100)), ['', 0, 0, 0, 0, 0]);
    return { title: `GST summary ${from} to ${to}`, columns: ['GST rate', 'Taxable value', 'CGST', 'SGST', 'IGST', 'Total tax'], rows: out.length ? [...out, tot] : [] };
  }
  if (report === 'stock') {
    const { rows } = await db.query(`${ITEM_SELECT} WHERE i.business_id = $1 AND i.is_active AND i.stock_enabled ORDER BY lower(i.name)`, [id]);
    return {
      title: 'Stock report',
      columns: ['Item', 'Unit', 'In stock', 'Cost price', 'Stock value (Rs)', 'Selling price'],
      rows: rows.map(itemJson).map((i) => [i.name, i.unit, Number(i.stock_qty), rs(i.purchase_price), rs(Number(i.stock_qty) * Number(i.purchase_price)), rs(i.selling_price)]),
    };
  }
  if (report === 'receivables') {
    const { rows } = await db.query(
      `SELECT COALESCE(NULLIF(i.party_name,''),'Cash Customer') AS party, SUM(i.grand_total - i.amount_paid) AS due
         FROM invoices i WHERE i.business_id = $1 AND i.affects_books AND i.status IN ('unpaid','partial') GROUP BY 1 ORDER BY due DESC`, [id]);
    return { title: 'Receivables', columns: ['Customer', 'Amount due (Rs)'], rows: rows.map((r) => [r.party, rs(r.due)]) };
  }
  throw Object.assign(new Error('Unknown report'), { status: 400 });
}

function render(t, format) {
  if (format === 'csv') return { type: 'text/csv; charset=utf-8', ext: 'csv', body: toCsv([t.columns, ...t.rows]) };
  if (format === 'xlsx') {
    return { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', ext: 'xlsx', body: writeXlsx([{ name: t.title.slice(0, 31), rows: [t.columns, ...t.rows] }]) };
  }
  return null;
}

module.exports = { REPORTS, table, render };
