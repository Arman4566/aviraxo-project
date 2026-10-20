// Payment reminders and promise-to-pay. Every function takes a db client (see receivables.js).
// Delivery model: the server decides WHO to remind, WHEN and WHAT to say, and hands the app ready-to-open
// WhatsApp / SMS / email links plus a UPI payload. The owner taps send. (Fully automatic sending would need
// a WhatsApp Business API account and a paid SMS gateway, which are credentials only the business can provide.)
const { notFound, badRequest } = require('../utils/errors');
const { todayIST } = require('../utils/time');
const { BALANCE_SQL } = require('./partyQueries');
const { DEFAULT_RULES, isRuleDue, strictest, renderMessage } = require('../utils/reminderLogic');
const { buildUpiUrl, whatsappUrl, smsUrl, mailtoUrl, normalizePhone, daysBetween } = require('../utils/format');
const { dueOf } = require('../utils/reminderLogic');

const RULE_COLS = ['name', 'trigger_type', 'offset_days', 'repeat_every_days', 'channel', 'tone', 'template', 'language', 'is_active'];

// ---------- rules ----------
async function ensureDefaultRules(db, businessId) {
  const { rows: [b] } = await db.query(`SELECT settings FROM businesses WHERE id = $1 FOR UPDATE`, [businessId]);
  if (b && b.settings && b.settings.remindersSeeded) return;
  for (const r of DEFAULT_RULES) {
    await db.query(
      `INSERT INTO reminder_rules (business_id, name, trigger_type, offset_days, repeat_every_days, channel, tone) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [businessId, r.name, r.trigger_type, r.offset_days, r.repeat_every_days, r.channel, r.tone]);
  }
  await db.query(`UPDATE businesses SET settings = jsonb_set(COALESCE(settings,'{}'::jsonb), '{remindersSeeded}', 'true') WHERE id = $1`, [businessId]);
}

async function listRules(db, businessId) {
  const { rows } = await db.query(`SELECT * FROM reminder_rules WHERE business_id = $1 ORDER BY trigger_type = 'after_due', offset_days DESC, id`, [businessId]);
  return rows;
}

function checkRule(r) {
  if (r.trigger_type === 'on_due' && r.offset_days) throw badRequest('offset_days must be 0 for on_due rules');
  if (r.repeat_every_days && r.trigger_type !== 'after_due') throw badRequest('Only after-due rules can repeat');
}

async function createRule(db, businessId, r) {
  checkRule(r);
  const { rows } = await db.query(
    `INSERT INTO reminder_rules (business_id, name, trigger_type, offset_days, repeat_every_days, channel, tone, template, language, is_active)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
    [businessId, r.name, r.trigger_type, r.offset_days || 0, r.repeat_every_days || null, r.channel || 'whatsapp', r.tone || 'friendly',
     r.template || '', r.language || 'en', r.is_active !== false]);
  return rows[0];
}

async function updateRule(db, businessId, id, patch) {
  const { rows: [cur] } = await db.query('SELECT * FROM reminder_rules WHERE id = $1 AND business_id = $2 FOR UPDATE', [id, businessId]);
  if (!cur) throw notFound('Reminder rule not found');
  const next = { ...cur, ...patch };
  checkRule(next);
  const { rows } = await db.query(
    `UPDATE reminder_rules SET name=$3, trigger_type=$4, offset_days=$5, repeat_every_days=$6, channel=$7, tone=$8, template=$9, language=$10,
            is_active=$11, updated_at=now() WHERE id=$1 AND business_id=$2 RETURNING *`,
    [id, businessId, ...RULE_COLS.map((k) => (k === 'repeat_every_days' ? next[k] || null : next[k]))]);
  return rows[0];
}

async function deleteRule(db, businessId, id) {
  const { rows } = await db.query('DELETE FROM reminder_rules WHERE id = $1 AND business_id = $2 RETURNING id', [id, businessId]);
  if (!rows[0]) throw notFound('Reminder rule not found');
}

// ---------- promises ----------
/** Keeps promise statuses honest: kept once the money arrived, broken when the date passed unpaid. */
async function refreshPromises(db, businessId, today = todayIST()) {
  await db.query(
    `UPDATE payment_promises pp SET status = 'kept', updated_at = now()
      WHERE pp.business_id = $1 AND pp.status = 'open' AND (
        (pp.invoice_id IS NOT NULL AND EXISTS (SELECT 1 FROM invoices i WHERE i.id = pp.invoice_id AND i.status IN ('paid','cancelled')))
        OR (pp.invoice_id IS NULL AND (SELECT (${BALANCE_SQL}) FROM parties p WHERE p.id = pp.party_id) <= 0))`, [businessId]);
  await db.query(
    `UPDATE payment_promises SET status = 'broken', updated_at = now() WHERE business_id = $1 AND status = 'open' AND promised_date < $2`,
    [businessId, today]);
}

async function createPromise(db, { businessId, userId, partyId, invoiceId, promisedDate, amount, note, today = todayIST() }) {
  if (promisedDate < today) throw badRequest('Promise date cannot be in the past');
  const { rows: [p] } = await db.query('SELECT id FROM parties WHERE id = $1 AND business_id = $2', [partyId, businessId]);
  if (!p) throw notFound('Party not found');
  if (invoiceId) {
    const { rows: [i] } = await db.query('SELECT id, party_id FROM invoices WHERE id = $1 AND business_id = $2', [invoiceId, businessId]);
    if (!i || i.party_id !== partyId) throw badRequest('Invoice does not belong to this party');
  }
  // A newer promise replaces the old open one for the same scope.
  await db.query(
    `UPDATE payment_promises SET status = 'cancelled', updated_at = now()
      WHERE business_id = $1 AND party_id = $2 AND status = 'open' AND invoice_id IS NOT DISTINCT FROM $3`, [businessId, partyId, invoiceId || null]);
  const { rows } = await db.query(
    `INSERT INTO payment_promises (business_id, party_id, invoice_id, promised_date, amount, note, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`, [businessId, partyId, invoiceId || null, promisedDate, amount || 0, note || '', userId]);
  return rows[0];
}

async function listPromises(db, businessId, { partyId = null, status = null, today = todayIST() } = {}) {
  await refreshPromises(db, businessId, today);
  const params = [businessId];
  const where = ['pp.business_id = $1'];
  if (partyId) { params.push(partyId); where.push(`pp.party_id = $${params.length}`); }
  if (status) { params.push(status); where.push(`pp.status = $${params.length}`); }
  const { rows } = await db.query(
    `SELECT pp.*, p.name AS party_name, i.invoice_no FROM payment_promises pp
       JOIN parties p ON p.id = pp.party_id LEFT JOIN invoices i ON i.id = pp.invoice_id
      WHERE ${where.join(' AND ')} ORDER BY pp.status = 'open' DESC, pp.promised_date`, params);
  return rows;
}

async function updatePromise(db, businessId, id, { status, promisedDate, note }) {
  const { rows: [cur] } = await db.query('SELECT * FROM payment_promises WHERE id = $1 AND business_id = $2 FOR UPDATE', [id, businessId]);
  if (!cur) throw notFound('Promise not found');
  const { rows } = await db.query(
    `UPDATE payment_promises SET status = $3, promised_date = $4, note = $5, updated_at = now() WHERE id = $1 AND business_id = $2 RETURNING *`,
    [id, businessId, status || cur.status, promisedDate || cur.promised_date, note !== undefined ? note : cur.note]);
  return rows[0];
}

// ---------- composing and the daily list ----------
const settingsOf = (business) => business.settings || {};

function links({ business, party, message, total, invoiceNo }) {
  const upiId = settingsOf(business).upiId || '';
  return {
    whatsapp_url: whatsappUrl(party.phone, message),
    sms_url: smsUrl(party.phone, message),
    email_url: mailtoUrl(party.email, `Payment reminder from ${business.name}`, message),
    upi_url: buildUpiUrl({ upiId, name: business.name, amount: total, note: invoiceNo ? `Invoice ${invoiceNo}` : 'Payment' }),
    has_phone: !!normalizePhone(party.phone),
  };
}

async function openInvoicesOf(db, businessId, partyId, ids = null) {
  const params = [businessId, partyId];
  let extra = '';
  if (ids && ids.length) { params.push(ids); extra = `AND id = ANY($${params.length}::bigint[])`; }
  const { rows } = await db.query(
    `SELECT id, invoice_no, invoice_date, due_date, grand_total, amount_paid FROM invoices
      WHERE business_id = $1 AND party_id = $2 AND affects_books AND status IN ('unpaid','partial') ${extra}
      ORDER BY COALESCE(due_date, invoice_date), id`, params);
  return rows;
}

/** Builds one reminder for a customer, on demand (the "Remind" button). */
async function compose(db, { business, partyId, invoiceIds = null, tone = null, language = 'en', template = '', messageOverride = '', today = todayIST() }) {
  const { rows: [party] } = await db.query(
    `SELECT p.*, (${BALANCE_SQL}) AS balance FROM parties p WHERE p.id = $1 AND p.business_id = $2`, [partyId, business.id]);
  if (!party) throw notFound('Party not found');
  const invoices = await openInvoicesOf(db, business.id, partyId, invoiceIds);
  let lines = invoices;
  if (!lines.length) {
    if (!(party.balance > 0)) throw badRequest('This customer has nothing pending');
    lines = [{ invoice_no: 'Opening balance', due_date: null, invoice_date: today, grand_total: party.balance, amount_paid: 0 }];
  }
  const total = lines.reduce((s, i) => s + (i.grand_total - i.amount_paid), 0);
  const maxLate = Math.max(0, ...lines.map((i) => daysBetween(dueOf(i), today)));
  const chosenTone = tone || (maxLate > 30 ? 'final' : maxLate > 0 ? 'firm' : 'friendly');
  const message = messageOverride || renderMessage({ tone: chosenTone, language, template, party: party.name, business: business.name, invoices: lines, upiId: settingsOf(business).upiId || '', today });
  return {
    party_id: party.id, party_name: party.name, tone: chosenTone, language, message, total_due: total,
    invoices: lines.map((i) => ({ id: i.id || null, invoice_no: i.invoice_no, due_date: i.due_date || null, balance: i.grand_total - i.amount_paid })),
    ...links({ business, party, message, total, invoiceNo: lines.length === 1 ? lines[0].invoice_no : null }),
  };
}

/** The "Reminders to send today" list: every rule that fires today, grouped into one message per customer. */
async function dueToday(db, { business, today = todayIST() }) {
  await ensureDefaultRules(db, business.id);
  await refreshPromises(db, business.id, today);
  const [{ rows: rules }, { rows: invs }, { rows: promises }, { rows: sent }] = await Promise.all([
    db.query('SELECT * FROM reminder_rules WHERE business_id = $1 AND is_active', [business.id]),
    db.query(
      `SELECT i.id, i.party_id, i.invoice_no, i.invoice_date, i.due_date, i.grand_total, i.amount_paid,
              p.name, p.phone, p.email, p.reminders_paused
         FROM invoices i JOIN parties p ON p.id = i.party_id
        WHERE i.business_id = $1 AND i.affects_books AND i.status IN ('unpaid','partial') AND p.is_active AND p.type IN ('customer','both')`, [business.id]),
    db.query(`SELECT party_id, invoice_id, promised_date FROM payment_promises WHERE business_id = $1 AND status = 'open' AND promised_date >= $2`, [business.id, today]),
    db.query('SELECT invoice_id, rule_id FROM reminder_log WHERE business_id = $1 AND sent_on = $2', [business.id, today]),
  ]);
  const doneToday = new Set(sent.map((s) => `${s.invoice_id}:${s.rule_id}`));
  const promiseFor = (inv) => promises.find((p) => p.party_id === inv.party_id && (p.invoice_id === null || p.invoice_id === inv.id));

  const byParty = new Map();
  for (const inv of invs) {
    if (inv.reminders_paused) continue;
    for (const rule of rules) {
      if (!isRuleDue(rule, inv, today)) continue;
      if (doneToday.has(`${inv.id}:${rule.id}`)) continue;
      if (rule.trigger_type === 'after_due' && promiseFor(inv)) continue;      // they promised a date; do not nag before it
      if (!byParty.has(inv.party_id)) byParty.set(inv.party_id, { inv: new Map(), hits: [] });
      const g = byParty.get(inv.party_id);
      g.inv.set(inv.id, inv);
      g.hits.push({ invoice_id: inv.id, rule });
    }
  }
  const out = [];
  for (const [partyId, g] of byParty) {
    const invoices = [...g.inv.values()];
    const tone = strictest(g.hits.map((h) => h.rule.tone));
    const lead = g.hits.find((h) => h.rule.tone === tone).rule;
    const first = invoices[0];
    const message = renderMessage({ tone, language: lead.language, template: lead.template, party: first.name, business: business.name, invoices, upiId: settingsOf(business).upiId || '', today });
    const total = invoices.reduce((s, i) => s + (i.grand_total - i.amount_paid), 0);
    out.push({
      party_id: partyId, party_name: first.name, channel: lead.channel, tone, message, total_due: total,
      invoices: invoices.map((i) => ({ id: i.id, invoice_no: i.invoice_no, due_date: dueOf(i), balance: i.grand_total - i.amount_paid })),
      items: g.hits.map((h) => ({ invoice_id: h.invoice_id, rule_id: h.rule.id })),
      ...links({ business, party: first, message, total, invoiceNo: invoices.length === 1 ? first.invoice_no : null }),
    });
  }
  out.sort((a, b) => b.total_due - a.total_due);
  return out;
}

/** Records that a reminder was sent (or skipped). Idempotent per invoice+rule+day, so a double tap does not double count. */
async function logReminder(db, { businessId, userId, partyId, channel, message, status = 'sent', items = [], totalDue = 0, today = todayIST() }) {
  const { rows: [p] } = await db.query('SELECT id FROM parties WHERE id = $1 AND business_id = $2', [partyId, businessId]);
  if (!p) throw notFound('Party not found');
  const rows = items.length ? items : [{ invoice_id: null, rule_id: null }];
  let written = 0;
  for (const it of rows) {
    if (it.invoice_id) {
      const { rows: dup } = await db.query(
        `SELECT 1 FROM reminder_log WHERE business_id = $1 AND invoice_id = $2 AND rule_id IS NOT DISTINCT FROM $3 AND sent_on = $4`,
        [businessId, it.invoice_id, it.rule_id || null, today]);
      if (dup[0]) continue;
    }
    await db.query(
      `INSERT INTO reminder_log (business_id, party_id, invoice_id, rule_id, channel, status, message, amount_due, sent_on, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [businessId, partyId, it.invoice_id || null, it.rule_id || null, channel, status, message || '', totalDue, today, userId]);
    written += 1;
  }
  return { logged: written };
}

async function listLog(db, businessId, { partyId = null, limit = 100 } = {}) {
  const params = [businessId];
  let where = 'l.business_id = $1';
  if (partyId) { params.push(partyId); where += ` AND l.party_id = $${params.length}`; }
  params.push(limit);
  const { rows } = await db.query(
    `SELECT l.id, l.party_id, p.name AS party_name, l.invoice_id, l.channel, l.status, l.message, l.amount_due, l.sent_on, l.created_at
       FROM reminder_log l JOIN parties p ON p.id = l.party_id WHERE ${where} ORDER BY l.created_at DESC, l.id DESC LIMIT $${params.length}`, params);
  return rows;
}

module.exports = {
  ensureDefaultRules, listRules, createRule, updateRule, deleteRule,
  refreshPromises, createPromise, listPromises, updatePromise,
  compose, dueToday, logReminder, listLog,
};
