const router = require('express').Router();
const { z } = require('zod');
const { query } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { TODAY_SQL } = require('../utils/time');
const { ITEM_SELECT, itemJson } = require('../services/itemQueries');
const { PARTY_SELECT, partyJson } = require('../services/partyQueries');
const fin = require('../services/finance');
const { forbidden } = require('../utils/errors');
const { can } = require('../utils/permissions');

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD');
const range = z.object({ from: isoDate, to: isoDate, group: z.enum(['day', 'party', 'item']).default('day') });
const num = (r) => Object.fromEntries(Object.entries(r).map(([k, v]) => [k, typeof v === 'string' && /^\d+$/.test(v) ? Number(v) : v]));

router.get('/sales', validate(range, 'query'), asyncHandler(async (req, res) => {
  const { from, to, group } = req.query;
  const p = [req.business.id, from, to];
  const base = `i.business_id = $1 AND i.affects_books AND i.status <> 'cancelled' AND i.invoice_date BETWEEN $2 AND $3`;
  let sql;
  if (group === 'party') {
    sql = `SELECT COALESCE(NULLIF(i.party_name, ''), 'Cash Customer') AS label, COUNT(*) AS invoices, SUM(i.grand_total) AS total
             FROM invoices i WHERE ${base} GROUP BY 1 ORDER BY total DESC`;
  } else if (group === 'item') {
    sql = `SELECT l.name AS label, SUM(l.qty) AS qty, SUM(l.line_total) AS total
             FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id WHERE ${base} GROUP BY 1 ORDER BY total DESC`;
  } else {
    sql = `SELECT i.invoice_date AS label, COUNT(*) AS invoices, SUM(i.grand_total) AS total
             FROM invoices i WHERE ${base} GROUP BY 1 ORDER BY 1`;
  }
  const { rows } = await query(sql, p);
  const out = rows.map(num);
  res.json({ from, to, group, rows: out, grand_total: out.reduce((s, r) => s + Number(r.total), 0) });
}));

// Who owes what, aged by days past the due date (invoice date when there is no due date).
router.get('/receivables', asyncHandler(async (req, res) => {
  const age = `${TODAY_SQL} - COALESCE(i.due_date, i.invoice_date)`;
  const due = 'i.grand_total - i.amount_paid';
  const { rows } = await query(
    `SELECT i.party_id, COALESCE(NULLIF(i.party_name, ''), 'Cash Customer') AS party, SUM(${due}) AS total_due,
            SUM(CASE WHEN ${age} <= 0 THEN ${due} ELSE 0 END) AS current,
            SUM(CASE WHEN ${age} BETWEEN 1 AND 30 THEN ${due} ELSE 0 END) AS d1_30,
            SUM(CASE WHEN ${age} BETWEEN 31 AND 60 THEN ${due} ELSE 0 END) AS d31_60,
            SUM(CASE WHEN ${age} BETWEEN 61 AND 90 THEN ${due} ELSE 0 END) AS d61_90,
            SUM(CASE WHEN ${age} > 90 THEN ${due} ELSE 0 END) AS d90_plus
       FROM invoices i
      WHERE i.business_id = $1 AND i.affects_books AND i.status IN ('unpaid','partial')
      GROUP BY i.party_id, 2 ORDER BY total_due DESC`, [req.business.id]);
  const out = rows.map(num);
  res.json({ rows: out, total_due: out.reduce((s, r) => s + Number(r.total_due), 0) });
}));

router.get('/stock', asyncHandler(async (req, res) => {
  const { rows } = await query(`${ITEM_SELECT} WHERE i.business_id = $1 AND i.is_active AND i.stock_enabled ORDER BY lower(i.name)`, [req.business.id]);
  const items = rows.map(itemJson).map((i) => ({ ...i, stock_value: Math.round(i.stock_qty * i.purchase_price) }));
  res.json({ items, total_value: items.reduce((s, i) => s + i.stock_value, 0) });
}));

// GST by rate: the base for GSTR-1 / GSTR-3B preparation (filing exports come later).
router.get('/tax-summary', validate(range.omit({ group: true }), 'query'), asyncHandler(async (req, res) => {
  const { from, to } = req.query;
  const { rows } = await query(
    `SELECT l.gst_slab AS gst_rate, SUM(l.taxable_value) AS taxable_value, SUM(l.cgst) AS cgst, SUM(l.sgst) AS sgst, SUM(l.igst) AS igst
       FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id
      WHERE i.business_id = $1 AND i.affects_books AND i.gst_enabled AND i.status <> 'cancelled' AND i.invoice_date BETWEEN $2 AND $3
      GROUP BY l.gst_slab ORDER BY l.gst_slab`, [req.business.id, from, to]);
  const out = rows.map((r) => ({ gst_rate: r.gst_rate, taxable_value: Number(r.taxable_value), cgst: Number(r.cgst), sgst: Number(r.sgst), igst: Number(r.igst) }));
  const sum = (k) => out.reduce((s, r) => s + r[k], 0);
  res.json({ from, to, rows: out, totals: { taxable_value: sum('taxable_value'), cgst: sum('cgst'), sgst: sum('sgst'), igst: sum('igst') } });
}));

router.get('/parties', asyncHandler(async (req, res) => {
  const { rows } = await query(`${PARTY_SELECT} WHERE p.business_id = $1 AND p.is_active`, [req.business.id]);
  const parties = rows.map(partyJson);
  const customers = parties.filter((p) => p.type === 'customer' || p.type === 'both').length;
  const suppliers = parties.filter((p) => p.type === 'supplier' || p.type === 'both').length;
  const topDues = parties.filter((p) => p.balance > 0).sort((a, b) => b.balance - a.balance).slice(0, 20);
  res.json({ customers, suppliers, top_dues: topDues });
}));

// ---- Phase 4: profit & loss, day book, cash & bank, cash flow, GST returns ----
const rangeOnly = range.omit({ group: true });
router.get('/profit-loss', validate(rangeOnly, 'query'), asyncHandler(async (req, res) => res.json(await fin.profitLoss({ query }, req.business, req.query))));
router.get('/day-book', validate(z.object({ date: isoDate }), 'query'), asyncHandler(async (req, res) => res.json(await fin.dayBook({ query }, req.business.id, req.query.date))));
router.get('/cash-flow', validate(rangeOnly, 'query'), asyncHandler(async (req, res) => res.json(await fin.cashFlow({ query }, req.business.id, req.query))));
router.get('/cash-bank', asyncHandler(async (req, res) => res.json(await fin.cashAndBank({ query }, req.business))));

const gstOnly = (req) => { if (!can(req.business.role, 'reports.gst')) throw forbidden('GST returns are only available to the owner, manager and accountant'); };
router.get('/gstr1', validate(rangeOnly, 'query'), asyncHandler(async (req, res) => { gstOnly(req); res.json(await fin.gstr1({ query }, req.business, req.query)); }));
router.get('/gstr3b', validate(rangeOnly, 'query'), asyncHandler(async (req, res) => { gstOnly(req); res.json(await fin.gstr3b({ query }, req.business, req.query)); }));

module.exports = router;
