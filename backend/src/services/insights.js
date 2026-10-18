// Phase 6: explainable "smart" features. Everything here is plain maths on the business's own data
// (no external AI service, nothing leaves the database), so every number can be traced.
const { todayIST } = require('../utils/time');
const { addDays, daysBetween, formatINR } = require('../utils/format');
const { riskScore, onTimeProbability } = require('../utils/risk');
const { isValidGstin } = require('../utils/invoiceMath');
const { OPEN_INVOICES, behaviourByParty } = require('./receivables');
const { ITEM_SELECT } = require('./itemQueries');
const n = (v) => Number(v || 0);

/** Risk detail for one customer: score, label and the reasons behind it. */
async function partyRisk(db, businessId, partyId) {
  const m = await behaviourByParty(db, businessId, partyId);
  return { party_id: partyId, ...riskScore(m.get(partyId) || {}) };
}

/**
 * 30-day cash forecast in weekly buckets. Money in = unpaid invoices weighted by how reliably each customer pays;
 * invoices already overdue are expected later and at half the probability. Money out = recurring expenses due in the
 * window plus the 90-day average of other expenses.
 */
async function cashForecast(db, businessId, { days = 28, today = todayIST() } = {}) {
  const end = addDays(today, days);
  const [{ rows: open }, behaviour, { rows: rec }, { rows: [avg] }, { rows: [bal] }] = await Promise.all([
    db.query(
      `SELECT o.id, o.party_id, o.invoice_no, o.due, COALESCE(i.due_date, i.invoice_date) AS due_date
         FROM (${OPEN_INVOICES}) o JOIN invoices i ON i.id = o.id`, [businessId]),
    behaviourByParty(db, businessId),
    db.query(`SELECT amount, recurring, next_due FROM expenses WHERE business_id = $1 AND kind = 'expense' AND recurring IS NOT NULL AND next_due IS NOT NULL AND next_due <= $2`, [businessId, end]),
    db.query(`SELECT COALESCE(SUM(amount), 0) AS total FROM expenses WHERE business_id = $1 AND kind = 'expense' AND recurring IS NULL AND entry_date > $2::date - 90 AND entry_date <= $2`, [businessId, today]),
    db.query(`SELECT COALESCE(SUM(CASE WHEN direction = 'in' THEN amount ELSE -amount END), 0) AS net FROM payments WHERE business_id = $1`, [businessId]),
  ]);
  const weeks = Math.ceil(days / 7);
  const buckets = Array.from({ length: weeks }, (_, i) => ({ week: i + 1, from: addDays(today, i * 7), to: addDays(today, Math.min(i * 7 + 6, days - 1)), expected_in: 0, expected_out: 0 }));
  const at = (iso) => Math.min(weeks - 1, Math.max(0, Math.floor(daysBetween(today, iso) / 7)));
  const riskCache = new Map();
  const prob = (pid) => {
    if (!riskCache.has(pid)) riskCache.set(pid, onTimeProbability(riskScore(behaviour.get(pid) || {})));
    return riskCache.get(pid);
  };
  let overdueExpected = 0;
  for (const inv of open) {
    const dueIso = String(inv.due_date).slice(0, 10);
    const p = prob(inv.party_id);
    if (dueIso < today) { buckets[0].expected_in += Math.round(inv.due * p * 0.5); overdueExpected += inv.due; continue; }
    if (dueIso <= end) buckets[at(dueIso)].expected_in += Math.round(inv.due * p);
  }
  for (const r of rec) {
    let d = String(r.next_due).slice(0, 10), guard = 0;
    while (d <= end && guard++ < 60) {
      buckets[at(d < today ? today : d)].expected_out += r.amount;
      d = addDays(d, r.recurring === 'weekly' ? 7 : r.recurring === 'monthly' ? 30 : 365);
    }
  }
  const dailyOther = n(avg.total) / 90;
  buckets.forEach((b) => { b.expected_out += Math.round(dailyOther * (daysBetween(b.from, b.to) + 1)); b.net = b.expected_in - b.expected_out; });
  let running = 0;
  buckets.forEach((b) => { running += b.net; b.cumulative_net = running; });
  const total = (k) => buckets.reduce((s, b) => s + b[k], 0);
  return {
    as_of: today, days, buckets, expected_in: total('expected_in'), expected_out: total('expected_out'), net: running,
    already_overdue: overdueExpected, cash_recorded_so_far: n(bal.net),
    method: 'Invoices are weighted by each customer\'s past on-time rate. Overdue invoices count at half weight in week 1. Expenses: recurring ones as scheduled, others at the 90-day average.',
  };
}

/** Turns numbers into plain-language cards. Pure, so it is unit-tested without a database. */
function buildInsights(d) {
  const out = [];
  if (d.sales_prev_week > 0 || d.sales_week > 0) {
    if (d.sales_prev_week > 0) {
      const pct = Math.round(((d.sales_week - d.sales_prev_week) / d.sales_prev_week) * 100);
      if (pct >= 10) out.push({ id: 'sales_up', severity: 'good', title: `Sales are up ${pct}% on last week`, detail: `${formatINR(d.sales_week)} in the last 7 days against ${formatINR(d.sales_prev_week)} the week before.` });
      else if (pct <= -10) out.push({ id: 'sales_down', severity: 'warn', title: `Sales are down ${Math.abs(pct)}% on last week`, detail: `${formatINR(d.sales_week)} in the last 7 days against ${formatINR(d.sales_prev_week)} the week before.` });
    } else out.push({ id: 'sales_new', severity: 'info', title: 'Sales picked up this week', detail: `${formatINR(d.sales_week)} in the last 7 days, nothing the week before.` });
  }
  if (d.overdue_total > 0) {
    const top = d.top_debtor;
    const share = d.receivable_total > 0 ? Math.round((d.overdue_total / d.receivable_total) * 100) : 0;
    out.push({ id: 'overdue', severity: share >= 40 ? 'warn' : 'info', title: `${formatINR(d.overdue_total)} is overdue (${share}% of what you are owed)`,
      detail: top ? `${top.name} owes the most: ${formatINR(top.balance)}.` : '', action: 'open_receivables' });
  }
  if (d.top_debtor && d.receivable_total > 0 && d.top_debtor.balance / d.receivable_total >= 0.5 && d.top_debtor.balance > 0)
    out.push({ id: 'concentration', severity: 'warn', title: `One customer is ${Math.round((d.top_debtor.balance / d.receivable_total) * 100)}% of your receivables`, detail: `${d.top_debtor.name}. A late payment from them would hurt cash flow.` });
  if (d.out_of_stock + d.low_stock > 0)
    out.push({ id: 'stock', severity: d.out_of_stock > 0 ? 'warn' : 'info', title: `${d.out_of_stock} out of stock, ${d.low_stock} running low`, detail: 'Open the low-stock list to reorder.', action: 'open_low_stock' });
  if (d.top_sellers && d.top_sellers.length)
    out.push({ id: 'top_sellers', severity: 'info', title: `Best sellers (30 days): ${d.top_sellers.map((s) => s.name).join(', ')}`, detail: d.top_sellers.map((s) => `${s.name} ${formatINR(s.total)}`).join(' · ') });
  if (d.slow_value > 0)
    out.push({ id: 'slow_stock', severity: 'info', title: `${formatINR(d.slow_value)} of stock has not sold in 30 days`, detail: `${d.slow_count} item(s). Consider a discount or bundle.` });
  if (d.forecast_net !== undefined && d.forecast_net < 0)
    out.push({ id: 'cash_gap', severity: 'warn', title: `Cash may fall short by ${formatINR(-d.forecast_net)} over the next 4 weeks`, detail: 'Expected payments are lower than expected expenses. Chase overdue invoices first.' });
  return out;
}

async function businessInsights(db, businessId, { today = todayIST() } = {}) {
  const [{ rows: [w] }, { rows: top }, { rows: [stock] }, { rows: [slow] }, { rows: debtors }, fc] = await Promise.all([
    db.query(`SELECT COALESCE(SUM(grand_total) FILTER (WHERE invoice_date BETWEEN $2::date - 6 AND $2), 0) AS cur,
                     COALESCE(SUM(grand_total) FILTER (WHERE invoice_date BETWEEN $2::date - 13 AND $2::date - 7), 0) AS prev
                FROM invoices WHERE business_id = $1 AND affects_books AND status <> 'cancelled'`, [businessId, today]),
    db.query(`SELECT l.name, SUM(l.line_total) AS total FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id
               WHERE i.business_id = $1 AND i.affects_books AND i.status <> 'cancelled' AND i.invoice_date BETWEEN $2::date - 29 AND $2
               GROUP BY l.name ORDER BY total DESC LIMIT 3`, [businessId, today]),
    db.query(`SELECT COUNT(*) FILTER (WHERE stock_qty <= 0) AS out_of_stock,
                     COUNT(*) FILTER (WHERE stock_qty > 0 AND low_stock_level > 0 AND stock_qty <= low_stock_level) AS low_stock
                FROM (${ITEM_SELECT} WHERE i.business_id = $1 AND i.is_active AND i.stock_enabled) x`, [businessId]),
    db.query(`SELECT COUNT(*) AS cnt, COALESCE(SUM(ROUND(x.stock_qty * x.purchase_price)), 0) AS val
                FROM (${ITEM_SELECT} WHERE i.business_id = $1 AND i.is_active AND i.stock_enabled) x
               WHERE x.stock_qty > 0 AND NOT EXISTS (SELECT 1 FROM invoice_lines l JOIN invoices v ON v.id = l.invoice_id
                      WHERE l.item_id = x.id AND v.status <> 'cancelled' AND v.invoice_date BETWEEN $2::date - 29 AND $2)`, [businessId, today]),
    db.query(`SELECT p.name, SUM(o.due) AS balance, COALESCE(SUM(o.due) FILTER (WHERE o.age > 0), 0) AS overdue
                FROM (${OPEN_INVOICES}) o JOIN parties p ON p.id = o.party_id GROUP BY p.name ORDER BY balance DESC`, [businessId]),
    cashForecast(db, businessId, { today }),
  ]);
  const receivable = debtors.reduce((s, r) => s + n(r.balance), 0);
  const insights = buildInsights({
    sales_week: n(w.cur), sales_prev_week: n(w.prev), overdue_total: debtors.reduce((s, r) => s + n(r.overdue), 0), receivable_total: receivable,
    top_debtor: debtors[0] ? { name: debtors[0].name, balance: n(debtors[0].balance) } : null,
    out_of_stock: n(stock.out_of_stock), low_stock: n(stock.low_stock),
    top_sellers: top.map((r) => ({ name: r.name, total: n(r.total) })), slow_value: n(slow.val), slow_count: n(slow.cnt), forecast_net: fc.net,
  });
  return { as_of: today, insights };
}

/** Health score 0-100: collections, liquidity of stock and profit direction. Each part is shown so it is not a black box. */
function healthScore({ overdue_share, stock_issue_share, margin_pct, sales_growth_pct }) {
  const clamp = (v) => Math.max(0, Math.min(100, v));
  const parts = [
    { name: 'Collections', weight: 0.4, score: clamp(100 - overdue_share * 100 * 1.5) },
    { name: 'Stock availability', weight: 0.2, score: clamp(100 - stock_issue_share * 100 * 2) },
    { name: 'Margin', weight: 0.25, score: margin_pct === null ? 50 : clamp(margin_pct * 3) },
    { name: 'Sales trend', weight: 0.15, score: sales_growth_pct === null ? 50 : clamp(50 + sales_growth_pct) },
  ];
  const score = Math.round(parts.reduce((s, p) => s + p.score * p.weight, 0));
  return { score, label: score >= 75 ? 'healthy' : score >= 50 ? 'okay' : 'needs attention', parts: parts.map((p) => ({ ...p, score: Math.round(p.score) })) };
}

/**
 * Sanity checks run BEFORE saving an invoice draft: duplicate bill, bad GSTIN, missing HSN, price below cost, tax-rate mismatch.
 * Returns warnings only; the server still decides whether to accept the invoice.
 */
async function checkInvoiceDraft(db, business, draft) {
  const warnings = [];
  const total = draft.total || 0;
  if (draft.party_id && total > 0) {
    const { rows: dup } = await db.query(
      `SELECT invoice_no, invoice_date FROM invoices WHERE business_id = $1 AND party_id = $2 AND grand_total = $3 AND affects_books AND status <> 'cancelled'
          AND created_at > now() - interval '2 days' ORDER BY id DESC LIMIT 1`, [business.id, draft.party_id, total]);
    if (dup[0]) warnings.push({ code: 'duplicate', message: `Looks like a duplicate of ${dup[0].invoice_no} (same customer and amount in the last 2 days)` });
  }
  if (draft.party_id) {
    const { rows: [p] } = await db.query('SELECT gstin, gst_registered, name FROM parties WHERE id = $1 AND business_id = $2', [draft.party_id, business.id]);
    if (p && p.gstin && !isValidGstin(p.gstin)) warnings.push({ code: 'bad_gstin', message: `${p.name}'s GSTIN ${p.gstin} is not valid` });
    if (p && p.gst_registered && !p.gstin) warnings.push({ code: 'missing_gstin', message: `${p.name} is marked GST-registered but has no GSTIN` });
  }
  const ids = (draft.lines || []).filter((l) => l.item_id).map((l) => l.item_id);
  const items = new Map();
  if (ids.length) {
    const { rows } = await db.query('SELECT id, name, purchase_price, gst_rate, hsn FROM items WHERE business_id = $1 AND id = ANY($2::bigint[])', [business.id, ids]);
    rows.forEach((r) => items.set(r.id, r));
  }
  for (const l of draft.lines || []) {
    const it = l.item_id ? items.get(l.item_id) : null;
    if (draft.gst_enabled && business.gst_registered && !l.hsn && !(it && it.hsn)) warnings.push({ code: 'missing_hsn', message: `"${l.name}" has no HSN code` });
    if (it && it.purchase_price > 0 && l.rate < it.purchase_price && !l.tax_inclusive) warnings.push({ code: 'below_cost', message: `"${l.name}" is priced below its purchase price (${formatINR(l.rate)} vs ${formatINR(it.purchase_price)})` });
    if (it && draft.gst_enabled && Number(l.gst_slab) !== Number(it.gst_rate) && it.gst_rate > 0) warnings.push({ code: 'tax_mismatch', message: `"${l.name}" uses ${l.gst_slab}% GST but the item is set to ${it.gst_rate}%` });
  }
  return { ok: warnings.length === 0, warnings };
}

module.exports = { partyRisk, cashForecast, buildInsights, businessInsights, healthScore, checkInvoiceDraft };
