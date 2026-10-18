// Profit & loss, day book, cash flow, cash & bank balances and GST return summaries.
// All money is integer paise. Every function takes a db client (see receivables.js).
const { TODAY_SQL } = require('../utils/time');
const { isValidGstin } = require('../utils/invoiceMath');
const n = (v) => Number(v || 0);

const SALE = `i.business_id = $1 AND i.affects_books AND i.status <> 'cancelled'`;
const B2CL_LIMIT = 25000000;   // Rs 2.5 lakh, in paise: inter-state unregistered invoices above this are reported one by one

async function profitLoss(db, business, { from, to }) {
  const [{ rows: [s] }, { rows: [c] }, { rows: exp }, { rows: [inc] }] = await Promise.all([
    db.query(`SELECT COALESCE(SUM(i.taxable_value),0) AS sales, COALESCE(SUM(i.tax_total),0) AS tax_collected, COUNT(*) AS invoices
                FROM invoices i WHERE ${SALE} AND i.invoice_date BETWEEN $2 AND $3`, [business.id, from, to]),
    db.query(`SELECT COALESCE(SUM(ROUND(l.qty * it.purchase_price)),0) AS cogs,
                     COUNT(*) FILTER (WHERE it.id IS NULL OR it.purchase_price = 0) AS lines_without_cost
                FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id LEFT JOIN items it ON it.id = l.item_id
               WHERE ${SALE} AND i.invoice_date BETWEEN $2 AND $3`, [business.id, from, to]),
    db.query(`SELECT category, SUM(amount - CASE WHEN $4 THEN gst_amount ELSE 0 END) AS total FROM expenses
               WHERE business_id = $1 AND kind = 'expense' AND entry_date BETWEEN $2 AND $3 GROUP BY category ORDER BY total DESC`,
      [business.id, from, to, !!business.gst_registered]),
    db.query(`SELECT COALESCE(SUM(amount),0) AS total FROM expenses WHERE business_id = $1 AND kind = 'income' AND entry_date BETWEEN $2 AND $3`, [business.id, from, to]),
  ]);
  const sales = n(s.sales), cogs = n(c.cogs);
  const expenses = exp.map((r) => ({ category: r.category, total: n(r.total) }));
  const expTotal = expenses.reduce((a, r) => a + r.total, 0);
  const gross = sales - cogs;
  return {
    from, to, invoices: n(s.invoices), sales, tax_collected: n(s.tax_collected),
    cost_of_goods: cogs, gross_profit: gross, gross_margin_pct: sales > 0 ? Math.round((gross / sales) * 1000) / 10 : null,
    expenses: expTotal, expenses_by_category: expenses, other_income: n(inc.total),
    net_profit: gross - expTotal + n(inc.total),
    lines_without_cost: n(c.lines_without_cost),
    note: 'Cost of goods uses each item\'s current purchase price. Input GST on expenses is excluded for GST-registered businesses.',
  };
}

async function dayBook(db, businessId, date) {
  const { rows } = await db.query(
    `SELECT * FROM (
        SELECT 'sale' AS type, i.id, i.invoice_no AS ref, COALESCE(NULLIF(i.party_name,''),'Cash Customer') AS name, i.grand_total AS amount, '' AS mode, i.created_at
          FROM invoices i WHERE ${SALE} AND i.invoice_date = $2
        UNION ALL
        SELECT 'payment_in', p.id, 'Receipt', COALESCE(pt.name,'Cash Customer'), p.amount, p.mode, p.created_at
          FROM payments p LEFT JOIN parties pt ON pt.id = p.party_id WHERE p.business_id = $1 AND p.direction = 'in' AND p.payment_date = $2
        UNION ALL
        SELECT 'payment_out', p.id, 'Payment', COALESCE(pt.name,'Supplier'), p.amount, p.mode, p.created_at
          FROM payments p LEFT JOIN parties pt ON pt.id = p.party_id WHERE p.business_id = $1 AND p.direction = 'out' AND p.payment_date = $2
        UNION ALL
        SELECT CASE WHEN e.kind = 'expense' THEN 'expense' ELSE 'income' END, e.id, e.category, COALESCE(NULLIF(e.note,''), e.category), e.amount, e.mode, e.created_at
          FROM expenses e WHERE e.business_id = $1 AND e.entry_date = $2
     ) x ORDER BY created_at, id`, [businessId, date]);
  const sum = (types) => rows.filter((r) => types.includes(r.type)).reduce((a, r) => a + n(r.amount), 0);
  return { date, entries: rows, sales: sum(['sale']), money_in: sum(['payment_in', 'income']), money_out: sum(['payment_out', 'expense']) };
}

const MODES = ['cash', 'upi', 'card', 'bank', 'cheque', 'other'];
/** Balance per payment mode: opening (from business settings.openingBalances) + money in - money out, all time. */
async function cashAndBank(db, business) {
  const { rows } = await db.query(
    `SELECT mode, SUM(inflow) AS money_in, SUM(outflow) AS money_out FROM (
        SELECT mode, amount AS inflow, 0 AS outflow FROM payments WHERE business_id = $1 AND direction = 'in'
        UNION ALL SELECT mode, 0, amount FROM payments WHERE business_id = $1 AND direction = 'out'
        UNION ALL SELECT mode, CASE WHEN kind = 'income' THEN amount ELSE 0 END, CASE WHEN kind = 'expense' THEN amount ELSE 0 END FROM expenses WHERE business_id = $1
     ) x GROUP BY mode`, [business.id]);
  const opening = (business.settings && business.settings.openingBalances) || {};
  const by = new Map(rows.map((r) => [r.mode, r]));
  const accounts = MODES.map((m) => {
    const r = by.get(m) || {};
    const o = Number.isFinite(opening[m]) ? opening[m] : 0;
    return { mode: m, opening: o, money_in: n(r.money_in), money_out: n(r.money_out), balance: o + n(r.money_in) - n(r.money_out) };
  }).filter((a) => a.opening || a.money_in || a.money_out || a.mode === 'cash');
  return { accounts, total_balance: accounts.reduce((s, a) => s + a.balance, 0) };
}

async function cashFlow(db, businessId, { from, to }) {
  const { rows } = await db.query(
    `SELECT d::date AS day,
            COALESCE(SUM(inflow),0) AS money_in, COALESCE(SUM(outflow),0) AS money_out
       FROM (
         SELECT payment_date AS d, amount AS inflow, 0 AS outflow FROM payments WHERE business_id = $1 AND direction = 'in'
         UNION ALL SELECT payment_date, 0, amount FROM payments WHERE business_id = $1 AND direction = 'out'
         UNION ALL SELECT entry_date, CASE WHEN kind = 'income' THEN amount ELSE 0 END, CASE WHEN kind = 'expense' THEN amount ELSE 0 END FROM expenses WHERE business_id = $1
       ) x WHERE d BETWEEN $2 AND $3 GROUP BY d ORDER BY d`, [businessId, from, to]);
  const days = rows.map((r) => ({ day: r.day, money_in: n(r.money_in), money_out: n(r.money_out), net: n(r.money_in) - n(r.money_out) }));
  const t = (k) => days.reduce((s, d) => s + d[k], 0);
  return { from, to, days, money_in: t('money_in'), money_out: t('money_out'), net: t('net') };
}

// ---------------- GST ----------------
const GST_INV = `i.business_id = $1 AND i.affects_books AND i.gst_enabled AND i.status <> 'cancelled' AND i.invoice_date BETWEEN $2 AND $3`;

/** GSTR-1 working: B2B, B2C large, B2C small, HSN summary and documents issued. Check against the portal before filing. */
async function gstr1(db, business, { from, to }) {
  const [{ rows: heads }, { rows: lines }, { rows: hsn }, { rows: docs }] = await Promise.all([
    db.query(`SELECT i.id, i.invoice_no, i.invoice_date, i.grand_total, i.place_of_supply, i.is_interstate, i.party_name, i.party_id, COALESCE(p.gstin,'') AS party_gstin
                FROM invoices i LEFT JOIN parties p ON p.id = i.party_id WHERE ${GST_INV} ORDER BY i.invoice_date, i.id`, [business.id, from, to]),
    db.query(`SELECT l.invoice_id, l.gst_slab AS rate, SUM(l.taxable_value) AS taxable_value, SUM(l.igst) AS igst, SUM(l.cgst) AS cgst, SUM(l.sgst) AS sgst
                FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id WHERE ${GST_INV} GROUP BY l.invoice_id, l.gst_slab ORDER BY l.invoice_id, l.gst_slab`, [business.id, from, to]),
    db.query(`SELECT l.hsn, l.unit, l.gst_slab AS rate, SUM(l.qty) AS qty, SUM(l.taxable_value) AS taxable_value, SUM(l.igst) AS igst, SUM(l.cgst) AS cgst, SUM(l.sgst) AS sgst, SUM(l.line_total) AS total_value
                FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id WHERE ${GST_INV} GROUP BY l.hsn, l.unit, l.gst_slab ORDER BY l.hsn, l.gst_slab`, [business.id, from, to]),
    db.query(`SELECT split_part(invoice_no,'-',1) AS series, MIN(invoice_no) AS from_no, MAX(invoice_no) AS to_no, COUNT(*) AS total, COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled
                FROM invoices WHERE business_id = $1 AND affects_books AND gst_enabled AND invoice_date BETWEEN $2 AND $3 GROUP BY 1 ORDER BY 1`, [business.id, from, to]),
  ]);
  const byInv = new Map();
  lines.forEach((l) => { if (!byInv.has(l.invoice_id)) byInv.set(l.invoice_id, []); byInv.get(l.invoice_id).push({ rate: n(l.rate), taxable_value: n(l.taxable_value), igst: n(l.igst), cgst: n(l.cgst), sgst: n(l.sgst) }); });

  const b2b = [], b2cl = [];
  const b2csMap = new Map();
  const warnings = [];
  for (const h of heads) {
    const items = byInv.get(h.id) || [];
    const registered = !!h.party_gstin;
    if (registered && !isValidGstin(h.party_gstin)) warnings.push(`${h.invoice_no}: customer GSTIN ${h.party_gstin} fails the checksum`);
    if (registered) {
      b2b.push({ gstin: h.party_gstin, party_name: h.party_name, invoice_no: h.invoice_no, invoice_date: h.invoice_date, invoice_value: h.grand_total, place_of_supply: h.place_of_supply, items });
    } else if (h.is_interstate && h.grand_total > B2CL_LIMIT) {
      b2cl.push({ invoice_no: h.invoice_no, invoice_date: h.invoice_date, invoice_value: h.grand_total, place_of_supply: h.place_of_supply, items });
    } else {
      for (const it of items) {
        const k = `${h.place_of_supply}|${it.rate}`;
        const cur = b2csMap.get(k) || { place_of_supply: h.place_of_supply, rate: it.rate, taxable_value: 0, igst: 0, cgst: 0, sgst: 0 };
        ['taxable_value', 'igst', 'cgst', 'sgst'].forEach((f) => { cur[f] += it[f]; });
        b2csMap.set(k, cur);
      }
    }
  }
  const missingHsn = hsn.filter((r) => !r.hsn).length;
  if (missingHsn) warnings.push('Some items have no HSN code; GSTR-1 needs HSN for most businesses');
  if (!business.gstin) warnings.push('Your business GSTIN is not set');
  const taxTotals = heads.length ? lines.reduce((a, l) => ({ taxable_value: a.taxable_value + n(l.taxable_value), igst: a.igst + n(l.igst), cgst: a.cgst + n(l.cgst), sgst: a.sgst + n(l.sgst) }), { taxable_value: 0, igst: 0, cgst: 0, sgst: 0 }) : { taxable_value: 0, igst: 0, cgst: 0, sgst: 0 };
  return {
    from, to, gstin: business.gstin || null, b2b, b2cl, b2cs: [...b2csMap.values()],
    hsn: hsn.map((r) => ({ hsn: r.hsn, unit: r.unit, rate: n(r.rate), qty: n(r.qty), taxable_value: n(r.taxable_value), igst: n(r.igst), cgst: n(r.cgst), sgst: n(r.sgst), total_value: n(r.total_value) })),
    documents: docs.map((d) => ({ series: d.series, from_no: d.from_no, to_no: d.to_no, total: n(d.total), cancelled: n(d.cancelled) })),
    totals: taxTotals, warnings,
  };
}

/** GSTR-3B working: outward supplies, nil-rated, inter-state to unregistered, and an ITC estimate from your expenses. */
async function gstr3b(db, business, { from, to }) {
  const [{ rows: [taxable] }, { rows: [nil] }, { rows: pos }, { rows: [itc] }] = await Promise.all([
    db.query(`SELECT COALESCE(SUM(l.taxable_value),0) AS taxable_value, COALESCE(SUM(l.igst),0) AS igst, COALESCE(SUM(l.cgst),0) AS cgst, COALESCE(SUM(l.sgst),0) AS sgst
                FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id WHERE ${GST_INV} AND l.gst_slab > 0`, [business.id, from, to]),
    db.query(`SELECT COALESCE(SUM(l.taxable_value),0) AS taxable_value FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id WHERE ${GST_INV} AND l.gst_slab = 0`, [business.id, from, to]),
    db.query(`SELECT i.place_of_supply, SUM(l.taxable_value) AS taxable_value, SUM(l.igst) AS igst
                FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id LEFT JOIN parties p ON p.id = i.party_id
               WHERE ${GST_INV} AND i.is_interstate AND COALESCE(p.gstin,'') = '' GROUP BY i.place_of_supply ORDER BY 1`, [business.id, from, to]),
    db.query(`SELECT COALESCE(SUM(gst_amount),0) AS gst FROM expenses WHERE business_id = $1 AND kind = 'expense' AND entry_date BETWEEN $2 AND $3`, [business.id, from, to]),
  ]);
  const outward = { taxable_value: n(taxable.taxable_value), igst: n(taxable.igst), cgst: n(taxable.cgst), sgst: n(taxable.sgst) };
  const outTax = outward.igst + outward.cgst + outward.sgst;
  const itcEst = n(itc.gst);
  return {
    from, to, gstin: business.gstin || null,
    outward_taxable: outward,                                   // 3.1(a)
    nil_rated: { taxable_value: n(nil.taxable_value) },         // 3.1(c)
    interstate_unregistered: pos.map((r) => ({ place_of_supply: r.place_of_supply, taxable_value: n(r.taxable_value), igst: n(r.igst) })),   // 3.2
    itc_estimate: itcEst,                                       // 4(A) - from the GST you recorded on expenses
    tax_payable_estimate: Math.max(0, outTax - itcEst),
    note: 'ITC is only what you recorded as GST on expenses and cannot be split into IGST/CGST/SGST here. Purchase invoices are not tracked yet, so verify with your CA before filing.',
  };
}

module.exports = { B2CL_LIMIT, profitLoss, dayBook, cashAndBank, cashFlow, gstr1, gstr3b };
