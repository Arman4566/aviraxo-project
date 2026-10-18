const test = require('node:test');
const assert = require('node:assert/strict');
const { formatINR, normalizePhone, buildUpiUrl, whatsappUrl, daysBetween, addDays, isValidUpiId } = require('../src/utils/format');
const { isRuleDue, renderMessage, strictest, DEFAULT_RULES } = require('../src/utils/reminderLogic');
const { riskScore, onTimeProbability } = require('../src/utils/risk');

test('formatINR uses Indian digit grouping', () => {
  assert.equal(formatINR(100000), '₹1,000');
  assert.equal(formatINR(123456789), '₹12,34,567.89');
  assert.equal(formatINR(50), '₹0.50');
  assert.equal(formatINR(-250000), '-₹2,500');
});

test('phone numbers are normalised for wa.me', () => {
  assert.equal(normalizePhone('98765 43210'), '919876543210');
  assert.equal(normalizePhone('+91-98765-43210'), '919876543210');
  assert.equal(normalizePhone('09876543210'), '919876543210');
  assert.equal(normalizePhone('12345'), null);
  assert.equal(normalizePhone(''), null);
  assert.equal(whatsappUrl('9876543210', 'Hi there'), 'https://wa.me/919876543210?text=Hi%20there');
  assert.equal(whatsappUrl('abc', 'x'), null);
});

test('UPI links validate the id and format the amount', () => {
  assert.ok(isValidUpiId('ramesh@okhdfc'));
  assert.ok(!isValidUpiId('not a upi id'));
  assert.equal(buildUpiUrl({ upiId: 'ramesh@okhdfc', name: 'Ramesh Electronics', amount: 123450, note: 'Invoice INV-1' }),
    'upi://pay?pa=ramesh%40okhdfc&pn=Ramesh%20Electronics&am=1234.50&cu=INR&tn=Invoice%20INV-1');
  assert.equal(buildUpiUrl({ upiId: 'bad', name: 'x' }), null);
});

test('date helpers', () => {
  assert.equal(daysBetween('2026-10-15', '2026-10-18'), 3);
  assert.equal(daysBetween('2026-10-18', '2026-10-15'), -3);
  assert.equal(addDays('2026-10-30', 3), '2026-11-02');
});

const inv = (due, total = 100000, paid = 0) => ({ due_date: due, invoice_date: '2026-09-01', grand_total: total, amount_paid: paid });
const rule = (o) => ({ is_active: true, offset_days: 0, repeat_every_days: null, ...o });

test('before_due / on_due fire exactly once on the right day', () => {
  const r = rule({ trigger_type: 'before_due', offset_days: 2 });
  assert.ok(isRuleDue(r, inv('2026-10-20'), '2026-10-18'));
  assert.ok(!isRuleDue(r, inv('2026-10-20'), '2026-10-17'));
  assert.ok(!isRuleDue(r, inv('2026-10-20'), '2026-10-19'));
  const d = rule({ trigger_type: 'on_due' });
  assert.ok(isRuleDue(d, inv('2026-10-18'), '2026-10-18'));
  assert.ok(!isRuleDue(d, inv('2026-10-18'), '2026-10-19'));
});

test('after_due fires at the offset, then every N days until paid', () => {
  const r = rule({ trigger_type: 'after_due', offset_days: 3, repeat_every_days: 7 });
  const i = inv('2026-10-01');
  const hits = [];
  for (let d = 1; d <= 31; d++) { const day = `2026-10-${String(d).padStart(2, '0')}`; if (isRuleDue(r, i, day)) hits.push(d); }
  assert.deepEqual(hits, [4, 11, 18, 25]);
  assert.ok(!isRuleDue(r, inv('2026-10-01', 100000, 100000), '2026-10-04'), 'paid invoices never fire');
  assert.ok(!isRuleDue({ ...r, is_active: false }, i, '2026-10-04'), 'inactive rules never fire');
  const once = rule({ trigger_type: 'after_due', offset_days: 3 });
  assert.ok(isRuleDue(once, i, '2026-10-04') && !isRuleDue(once, i, '2026-10-11'));
});

test('invoice without a due date uses its invoice date', () => {
  const r = rule({ trigger_type: 'on_due' });
  assert.ok(isRuleDue(r, { invoice_date: '2026-10-18', grand_total: 1, amount_paid: 0 }, '2026-10-18'));
});

test('messages carry party, amount, invoice list and the UPI id; tones escalate', () => {
  const invoices = [{ invoice_no: 'INV-00007', due_date: '2026-10-10', grand_total: 150000, amount_paid: 50000 }];
  const m = renderMessage({ tone: 'firm', party: 'Suresh', business: 'Ramesh Electronics', invoices, upiId: 'ramesh@okhdfc', today: '2026-10-18' });
  assert.match(m, /Suresh/); assert.match(m, /Ramesh Electronics/); assert.match(m, /INV-00007/); assert.match(m, /₹1,000/);
  assert.match(m, /ramesh@okhdfc/); assert.match(m, /overdue/);
  assert.ok(!/\{\w+\}/.test(m), 'no unfilled placeholders');
  const hi = renderMessage({ tone: 'friendly', language: 'hi', party: 'सुरेश', business: 'रमेश', invoices, today: '2026-10-18' });
  assert.match(hi, /नमस्ते/); assert.match(hi, /₹1,000/);
  const fin = renderMessage({ tone: 'final', party: 'S', business: 'B', invoices, today: '2026-10-18' });
  assert.match(fin, /8 days overdue/);
  const custom = renderMessage({ template: 'Pay {amount} for {invoice_no} by {due_date}', party: 'S', business: 'B', invoices, today: '2026-10-18' });
  assert.equal(custom, 'Pay ₹1,000 for INV-00007 by 10 Oct 2026');
  assert.equal(strictest(['friendly', 'final', 'firm']), 'final');
  assert.equal(DEFAULT_RULES.length, 3);
});

test('risk score: reliable payer is low, chronic late payer is high, newcomer is "new"', () => {
  const good = riskScore({ paid_amount: 1000000, on_time_amount: 1000000, weighted_days_late: 0, overdue_amount: 0, outstanding_amount: 50000, max_days_overdue: 0 });
  assert.equal(good.label, 'low');
  const bad = riskScore({ paid_amount: 1000000, on_time_amount: 100000, weighted_days_late: 1000000 * 40, overdue_amount: 300000, outstanding_amount: 300000, max_days_overdue: 75 });
  assert.equal(bad.label, 'high');
  assert.ok(bad.score > good.score);
  assert.deepEqual(riskScore({}).label, 'new');
  assert.ok(onTimeProbability(good) > onTimeProbability(bad));
  assert.ok(bad.reasons.length >= 2);
});
