/**
 * Deterministic invoice maths. ALL money is integer paise; no float leaves this module.
 * The server always computes totals; the app's preview is only a preview (Day 1 rule: AI/UI suggest, server decides).
 *
 * Per line (matches the app's own preview maths):
 *   base      = round(qty * rate)
 *   discount  = percent ? round(base * pct / 100) : min(flat paise, base)
 *   after     = base - discount
 *   exclusive: taxable = after,                              tax = round(taxable * slab / 100)
 *   inclusive: taxable = round(after * 100 / (100 + slab)),  tax = after - taxable
 *   tax is 0 when GST is not enabled for the invoice
 *   intra-state: cgst = floor(tax / 2), sgst = tax - cgst   (cgst + sgst == tax exactly)
 *   inter-state: igst = tax
 *   line_total = taxable + tax
 * Invoice totals are plain sums; there is no rupee round-off, so what the preview shows is what is saved.
 */
const { badRequest } = require('./errors');

const round = (n) => Math.round(n);

function computeLine(line, { gstEnabled, interstate }) {
  const { qty, rate, discount_is_percent = true, discount_value = 0, gst_slab = 0, tax_inclusive = false } = line;
  if (!(qty > 0)) throw badRequest('qty must be greater than 0');
  if (!Number.isInteger(rate) || rate < 0) throw badRequest('rate must be a non-negative integer (paise)');
  if (!(discount_value >= 0)) throw badRequest('discount cannot be negative');
  if (discount_is_percent && discount_value > 100) throw badRequest('discount percent cannot exceed 100');
  if (!discount_is_percent && !Number.isInteger(discount_value)) throw badRequest('flat discount must be an integer (paise)');

  const base = round(qty * rate);
  const discountAmount = discount_is_percent ? round((base * discount_value) / 100) : Math.min(discount_value, base);
  const after = base - discountAmount;
  const slab = gstEnabled ? gst_slab : 0;

  let taxable;
  let tax;
  if (tax_inclusive && slab > 0) {
    taxable = round((after * 100) / (100 + slab));
    tax = after - taxable;
  } else {
    taxable = after;
    tax = round((taxable * slab) / 100);
  }

  let cgst = 0, sgst = 0, igst = 0;
  if (interstate) {
    igst = tax;
  } else {
    cgst = Math.floor(tax / 2);
    sgst = tax - cgst;
  }

  return {
    line_base: base,
    discount_amount: discountAmount,
    taxable_value: taxable,
    tax_amount: tax,
    cgst, sgst, igst,
    line_total: taxable + tax,
  };
}

function computeInvoice(lines, { gstEnabled, interstate }) {
  const computed = lines.map((l) => computeLine(l, { gstEnabled, interstate }));
  const sum = (k) => computed.reduce((a, c) => a + c[k], 0);
  return {
    lines: computed,
    subtotal: sum('line_base'),
    discount_total: sum('discount_amount'),
    taxable_value: sum('taxable_value'),
    tax_total: sum('tax_amount'),
    cgst: sum('cgst'),
    sgst: sum('sgst'),
    igst: sum('igst'),
    grand_total: sum('line_total'),
  };
}

// GSTIN: 2-digit state, 10-char PAN, entity digit, 'Z', checksum char (checksum per GSTN spec).
const GSTIN_CHARS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
function isValidGstin(gstin) {
  if (typeof gstin !== 'string') return false;
  const g = gstin.trim().toUpperCase();
  if (!/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/.test(g)) return false;
  let sum = 0;
  for (let i = 0; i < 14; i++) {
    const v = GSTIN_CHARS.indexOf(g[i]) * (i % 2 === 0 ? 1 : 2);
    sum += Math.floor(v / 36) + (v % 36);
  }
  return GSTIN_CHARS[(36 - (sum % 36)) % 36] === g[14];
}

module.exports = { computeLine, computeInvoice, isValidGstin };
