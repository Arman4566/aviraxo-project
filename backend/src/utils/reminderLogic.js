// Pure reminder logic: which rules fire today, and what the message says. No database access here.
const { daysBetween, formatINR, prettyDate } = require('./format');

/** Starter rules created for every new business; the owner can edit or delete them. */
const DEFAULT_RULES = [
  { name: '2 days before due', trigger_type: 'before_due', offset_days: 2, repeat_every_days: null, channel: 'whatsapp', tone: 'friendly' },
  { name: 'On the due date', trigger_type: 'on_due', offset_days: 0, repeat_every_days: null, channel: 'whatsapp', tone: 'friendly' },
  { name: '3 days overdue, then weekly', trigger_type: 'after_due', offset_days: 3, repeat_every_days: 7, channel: 'whatsapp', tone: 'firm' },
];

const dueOf = (inv) => String(inv.due_date || inv.invoice_date).slice(0, 10);

/** True when `rule` should nudge about `inv` on `today` (both ISO dates). Paid/cancelled invoices never fire. */
function isRuleDue(rule, inv, today) {
  if (!rule.is_active || inv.grand_total - inv.amount_paid <= 0) return false;
  const due = dueOf(inv);
  const offset = rule.offset_days || 0;
  const sinceDue = daysBetween(due, today);               // negative before the due date
  if (rule.trigger_type === 'before_due') return sinceDue === -offset;
  if (rule.trigger_type === 'on_due') return sinceDue === 0;
  // after_due: first on due + offset, then every repeat_every_days while unpaid
  if (sinceDue < offset) return false;
  if (sinceDue === offset) return true;
  return !!rule.repeat_every_days && (sinceDue - offset) % rule.repeat_every_days === 0;
}

const TONE_ORDER = { friendly: 0, firm: 1, final: 2 };
const strictest = (tones) => tones.reduce((a, b) => (TONE_ORDER[b] > TONE_ORDER[a] ? b : a), 'friendly');

const TEXT = {
  en: {
    friendly: 'Hello {party}, a gentle reminder from {business}: {invoice_list}. Total pending: {amount}. {pay_line}Thank you!',
    firm: 'Dear {party}, your payment to {business} is overdue. {invoice_list}. Total pending: {amount}. {pay_line}Please clear it at the earliest.',
    final: 'Dear {party}, this is a final reminder from {business}. {invoice_list}. Total pending: {amount}, now {days_overdue} days overdue. {pay_line}Kindly pay today or contact us.',
    one: '{invoice_no} for {amount} (due {due_date})',
    pay: 'Pay via UPI: {upi_id}. ',
  },
  hi: {
    friendly: 'नमस्ते {party}, {business} की ओर से याद दिलाना: {invoice_list}। कुल बकाया: {amount}। {pay_line}धन्यवाद!',
    firm: 'प्रिय {party}, {business} को आपका भुगतान बकाया है। {invoice_list}। कुल बकाया: {amount}। {pay_line}कृपया जल्द भुगतान करें।',
    final: 'प्रिय {party}, {business} की ओर से यह अंतिम अनुस्मारक है। {invoice_list}। कुल बकाया: {amount}, {days_overdue} दिन से अधिक देर। {pay_line}कृपया आज ही भुगतान करें या हमसे संपर्क करें।',
    one: '{invoice_no} – {amount} (देय {due_date})',
    pay: 'UPI से भुगतान करें: {upi_id}। ',
  },
};

const fill = (tpl, vars) => tpl.replace(/\{(\w+)\}/g, (m, k) => (vars[k] !== undefined ? String(vars[k]) : m));

/**
 * Builds the reminder text. invoices: [{invoice_no, due_date, invoice_date, grand_total, amount_paid}].
 * A custom `template` may use {party} {business} {amount} {invoice_list} {invoice_no} {due_date} {days_overdue} {count} {upi_id}.
 */
function renderMessage({ tone = 'friendly', language = 'en', template = '', party, business, invoices, upiId = '', today }) {
  const t = TEXT[language] || TEXT.en;
  const bal = (i) => i.grand_total - i.amount_paid;
  const total = invoices.reduce((s, i) => s + bal(i), 0);
  const list = invoices.map((i) => fill(t.one, { invoice_no: i.invoice_no, amount: formatINR(bal(i)), due_date: prettyDate(dueOf(i)) })).join('; ');
  const maxLate = invoices.reduce((m, i) => Math.max(m, today ? daysBetween(dueOf(i), today) : 0), 0);
  const first = invoices[0] || {};
  const vars = {
    party, business, amount: formatINR(total), invoice_list: list, count: invoices.length,
    invoice_no: first.invoice_no || '', due_date: first.invoice_no ? prettyDate(dueOf(first)) : '',
    days_overdue: Math.max(maxLate, 0), upi_id: upiId,
    pay_line: upiId ? fill(t.pay, { upi_id: upiId }) : '',
  };
  return fill(template && template.trim() ? template : t[tone] || t.friendly, vars).replace(/\s+/g, ' ').trim();
}

module.exports = { DEFAULT_RULES, isRuleDue, strictest, renderMessage, dueOf };
