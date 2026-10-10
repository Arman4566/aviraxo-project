const test = require('node:test');
const assert = require('node:assert/strict');
const { computeLine, computeInvoice, isValidGstin } = require('../src/utils/invoiceMath');

const intra = { gstEnabled: true, interstate: false };
const inter = { gstEnabled: true, interstate: true };

test('exclusive 18% intra-state splits into equal CGST/SGST', () => {
  const r = computeLine({ qty: 2, rate: 50000, gst_slab: 18 }, intra);
  assert.deepEqual([r.line_base, r.taxable_value, r.tax_amount, r.cgst, r.sgst, r.igst, r.line_total], [100000, 100000, 18000, 9000, 9000, 0, 118000]);
});

test('inter-state puts all tax in IGST', () => {
  const r = computeLine({ qty: 1, rate: 100000, gst_slab: 12 }, inter);
  assert.deepEqual([r.cgst, r.sgst, r.igst, r.line_total], [0, 0, 12000, 112000]);
});

test('GST off: no tax whatever the slab says', () => {
  const r = computeLine({ qty: 1, rate: 100000, gst_slab: 18 }, { gstEnabled: false, interstate: false });
  assert.deepEqual([r.tax_amount, r.line_total], [0, 100000]);
});

test('percent discount is taken before tax (matches the app preview)', () => {
  const r = computeLine({ qty: 3, rate: 50000, discount_is_percent: true, discount_value: 10, gst_slab: 18 }, intra);
  assert.deepEqual([r.line_base, r.discount_amount, r.taxable_value, r.tax_amount, r.line_total], [150000, 15000, 135000, 24300, 159300]);
});

test('flat discount is capped at the line amount', () => {
  const r = computeLine({ qty: 1, rate: 10000, discount_is_percent: false, discount_value: 99999, gst_slab: 0 }, intra);
  assert.equal(r.discount_amount, 10000);
  assert.equal(r.line_total, 0);
});

test('tax-inclusive price backs tax out and totals back to the entered price', () => {
  const r = computeLine({ qty: 1, rate: 11800, gst_slab: 18, tax_inclusive: true }, intra);
  assert.deepEqual([r.taxable_value, r.cgst + r.sgst, r.line_total], [10000, 1800, 11800]);
});

test('odd tax paise: CGST + SGST always equals the tax exactly', () => {
  const r = computeLine({ qty: 1, rate: 101, gst_slab: 5 }, intra); // tax = round(5.05) = 5
  assert.equal(r.cgst + r.sgst, r.tax_amount);
  assert.deepEqual([r.cgst, r.sgst], [2, 3]);
});

test('fractional quantity is rounded to whole paise', () => {
  assert.equal(computeLine({ qty: 0.5, rate: 999, gst_slab: 0 }, intra).line_total, 500);
});

test('invoice totals are plain sums and always reconcile', () => {
  const lines = [
    { qty: 3, rate: 12345, discount_is_percent: false, discount_value: 500, gst_slab: 18 },
    { qty: 1.5, rate: 9999, gst_slab: 5, tax_inclusive: true },
    { qty: 7, rate: 4321, discount_value: 12.5, gst_slab: 28 },
  ];
  for (const ctx of [intra, inter, { gstEnabled: false, interstate: false }]) {
    const inv = computeInvoice(lines, ctx);
    assert.equal(inv.taxable_value + inv.tax_total, inv.grand_total);
    assert.equal(inv.cgst + inv.sgst + inv.igst, inv.tax_total);
    assert.equal(inv.subtotal - inv.discount_total >= inv.taxable_value - 1, true);
    assert.equal(inv.lines.reduce((s, l) => s + l.line_total, 0), inv.grand_total);
  }
});

test('rejects bad input', () => {
  assert.throws(() => computeLine({ qty: 0, rate: 100 }, intra), /qty/);
  assert.throws(() => computeLine({ qty: 1, rate: 10.5 }, intra), /integer/);
  assert.throws(() => computeLine({ qty: 1, rate: 100, discount_value: 150 }, intra), /percent/);
  assert.throws(() => computeLine({ qty: 1, rate: 100, discount_is_percent: false, discount_value: 1.5 }, intra), /flat/);
});

test('GSTIN checksum validation', () => {
  assert.equal(isValidGstin('27AAPFU0939F1ZV'), true);
  assert.equal(isValidGstin('27AAPFU0939F1ZX'), false);
  assert.equal(isValidGstin('123'), false);
  assert.equal(isValidGstin(undefined), false);
});
