// Outstanding payments (every function takes a db client, like the Phase 1 services, so it is testable against PostgreSQL): who owes what, how old it is, and what was already done about it.
const { TODAY_SQL } = require('../utils/time');
const { BALANCE_SQL } = require('./partyQueries');
const { riskScore } = require('../utils/risk');

const BUCKETS = ['not_due', 'd1_30', 'd31_60', 'd61_90', 'd90_plus'];
const emptyBuckets = () => Object.fromEntries(BUCKETS.map((b) => [b, 0]));
const addTo = (acc, other) => BUCKETS.forEach((b) => { acc[b] += Number(other[b] || 0); });

// Unpaid sale invoices with their age in days past due (invoice date when no due date was set).
const OPEN_INVOICES = `
  SELECT i.id, i.party_id, i.invoice_no, i.invoice_date, i.due_date, i.grand_total, i.amount_paid,
         i.grand_total - i.amount_paid AS due,
         ${TODAY_SQL} - COALESCE(i.due_date, i.invoice_date) AS age
    FROM invoices i
   WHERE i.business_id = $1 AND i.affects_books AND i.status IN ('unpaid','partial') AND i.party_id IS NOT NULL`;

const BUCKET_COLS = `
  COALESCE(SUM(due) FILTER (WHERE age <= 0), 0)            AS not_due,
  COALESCE(SUM(due) FILTER (WHERE age BETWEEN 1 AND 30), 0)  AS d1_30,
  COALESCE(SUM(due) FILTER (WHERE age BETWEEN 31 AND 60), 0) AS d31_60,
  COALESCE(SUM(due) FILTER (WHERE age BETWEEN 61 AND 90), 0) AS d61_90,
  COALESCE(SUM(due) FILTER (WHERE age > 90), 0)              AS d90_plus`;

/** Payment behaviour per party, from invoices already settled (allocations) plus what is overdue now. */
async function behaviourByParty(db, businessId, partyId = null) {
  const params = [businessId];
  const only = partyId ? (params.push(partyId), `AND i.party_id = $${params.length}`) : '';
  const { rows: hist } = await db.query(
    `SELECT i.party_id,
            SUM(a.amount) AS paid_amount,
            SUM(a.amount) FILTER (WHERE py.payment_date <= COALESCE(i.due_date, i.invoice_date) + 3) AS on_time_amount,
            SUM(a.amount * (py.payment_date - COALESCE(i.due_date, i.invoice_date))) AS weighted_days_late
       FROM payment_allocations a
       JOIN payments py ON py.id = a.payment_id
       JOIN invoices i ON i.id = a.invoice_id
      WHERE i.business_id = $1 AND i.party_id IS NOT NULL ${only}
      GROUP BY i.party_id`, params);
  const { rows: now } = await db.query(
    `SELECT party_id, SUM(due) AS outstanding_amount, COALESCE(SUM(due) FILTER (WHERE age > 0), 0) AS overdue_amount,
            COALESCE(MAX(age) FILTER (WHERE age > 0), 0) AS max_days_overdue
       FROM (${OPEN_INVOICES} ${only.replace('i.party_id', 'party_id')}) o GROUP BY party_id`, params);
  const map = new Map();
  hist.forEach((h) => map.set(h.party_id, { paid_amount: Number(h.paid_amount), on_time_amount: Number(h.on_time_amount || 0), weighted_days_late: Number(h.weighted_days_late || 0) }));
  now.forEach((n) => map.set(n.party_id, { ...(map.get(n.party_id) || {}), outstanding_amount: Number(n.outstanding_amount), overdue_amount: Number(n.overdue_amount), max_days_overdue: n.max_days_overdue }));
  return map;
}

/** Headline numbers for the "To Collect" card. */
async function summary(db, businessId) {
  const { rows: [r] } = await db.query(
    `SELECT COALESCE(SUM(due), 0) AS invoice_outstanding,
            COALESCE(SUM(due) FILTER (WHERE age > 0), 0) AS overdue,
            COUNT(DISTINCT party_id) FILTER (WHERE age > 0) AS overdue_parties,
            COUNT(*) FILTER (WHERE age > 0) AS overdue_invoices,
            COALESCE(SUM(due) FILTER (WHERE age = 0), 0) AS due_today,
            COALESCE(SUM(due) FILTER (WHERE age BETWEEN -7 AND -1), 0) AS due_next_7_days
       FROM (${OPEN_INVOICES}) o`, [businessId]);
  const { rows: [t] } = await db.query(
    `SELECT COALESCE(SUM(GREATEST(bal, 0)), 0) AS total_receivable, COALESCE(SUM(-LEAST(bal, 0)), 0) AS advances_held
       FROM (SELECT (${BALANCE_SQL}) AS bal FROM parties p
              WHERE p.business_id = $1 AND p.is_active AND p.type IN ('customer','both')) x`, [businessId]);
  const { rows: [c] } = await db.query(
    `SELECT COALESCE(SUM(amount), 0) AS collected_this_month FROM payments
      WHERE business_id = $1 AND direction = 'in' AND payment_date >= date_trunc('month', ${TODAY_SQL})::date`, [businessId]);
  const { rows: [s] } = await db.query(
    `SELECT COALESCE(SUM(grand_total), 0) AS credit_sales_90d FROM invoices
      WHERE business_id = $1 AND affects_books AND status <> 'cancelled' AND party_id IS NOT NULL
        AND invoice_date >= ${TODAY_SQL} - 90`, [businessId]);
  const dso = s.credit_sales_90d > 0 ? Math.round((t.total_receivable / s.credit_sales_90d) * 90) : null;
  return {
    total_receivable: t.total_receivable, advances_held: t.advances_held,
    overdue: r.overdue, overdue_parties: Number(r.overdue_parties), overdue_invoices: Number(r.overdue_invoices),
    due_today: r.due_today, due_next_7_days: r.due_next_7_days,
    collected_this_month: c.collected_this_month,
    days_sales_outstanding: dso,
  };
}

/** Aging report: totals per bucket plus one row per customer. `other` = opening balance net of unallocated advances. */
async function aging(db, businessId) {
  const { rows } = await db.query(
    `SELECT p.id AS party_id, p.name, p.phone, (${BALANCE_SQL}) AS balance,
            COALESCE(o.not_due, 0) AS not_due, COALESCE(o.d1_30, 0) AS d1_30, COALESCE(o.d31_60, 0) AS d31_60,
            COALESCE(o.d61_90, 0) AS d61_90, COALESCE(o.d90_plus, 0) AS d90_plus
       FROM parties p
       LEFT JOIN (SELECT party_id, ${BUCKET_COLS} FROM (${OPEN_INVOICES}) x GROUP BY party_id) o ON o.party_id = p.id
      WHERE p.business_id = $1 AND p.is_active AND p.type IN ('customer','both')`, [businessId]);
  const totals = emptyBuckets();
  let other = 0;
  const parties = [];
  for (const r of rows) {
    const inInvoices = BUCKETS.reduce((s, b) => s + Number(r[b]), 0);
    const rest = Number(r.balance) - inInvoices;     // opening balance / unallocated advance
    if (Number(r.balance) <= 0 && inInvoices === 0) continue;
    const buckets = Object.fromEntries(BUCKETS.map((b) => [b, Number(r[b])]));
    addTo(totals, buckets);
    other += rest;
    parties.push({ party_id: r.party_id, name: r.name, phone: r.phone, balance: Number(r.balance), other: rest, ...buckets });
  }
  parties.sort((a, b) => b.balance - a.balance);
  return { as_of: null, buckets: { ...totals, other }, total: parties.reduce((s, p) => s + p.balance, 0), parties };
}

/** Customers who owe money, with reminder and promise status and a risk label. Sorted by what matters most to chase. */
async function outstandingParties(db, businessId, { sort = 'overdue', bucket = null } = {}) {
  const a = await aging(db, businessId);
  const ids = a.parties.map((p) => p.party_id);
  if (!ids.length) return { parties: [], total: 0 };
  const [{ rows: meta }, { rows: last }, { rows: prom }, behaviour, { rows: oldest }] = await Promise.all([
    db.query('SELECT id, reminders_paused, credit_limit, payment_term, email FROM parties WHERE business_id = $1 AND id = ANY($2::bigint[])', [businessId, ids]),
    db.query(`SELECT party_id, MAX(sent_on) AS last_reminder_on, COUNT(*) FILTER (WHERE sent_on >= ${TODAY_SQL} - 30) AS reminders_30d
             FROM reminder_log WHERE business_id = $1 AND status = 'sent' AND party_id = ANY($2::bigint[]) GROUP BY party_id`, [businessId, ids]),
    db.query(`SELECT DISTINCT ON (party_id) party_id, promised_date, amount FROM payment_promises
            WHERE business_id = $1 AND status = 'open' AND party_id = ANY($2::bigint[]) ORDER BY party_id, promised_date`, [businessId, ids]),
    behaviourByParty(db, businessId),
    db.query(`SELECT party_id, MAX(age) AS oldest_days_overdue FROM (${OPEN_INVOICES}) o WHERE age > 0 GROUP BY party_id`, [businessId]),
  ]);
  const by = (arr, k = 'party_id') => new Map(arr.map((r) => [r[k], r]));
  const mMeta = by(meta, 'id'), mLast = by(last), mProm = by(prom), mOld = by(oldest);
  let list = a.parties.map((p) => {
    const m = mMeta.get(p.party_id) || {};
    const overdue = p.d1_30 + p.d31_60 + p.d61_90 + p.d90_plus;
    const risk = riskScore(behaviour.get(p.party_id) || {});
    return {
      ...p, overdue, oldest_days_overdue: mOld.get(p.party_id)?.oldest_days_overdue || 0,
      credit_limit: m.credit_limit || 0, over_credit_limit: !!m.credit_limit && p.balance > m.credit_limit,
      payment_term: m.payment_term, has_email: !!m.email, reminders_paused: !!m.reminders_paused,
      last_reminder_on: mLast.get(p.party_id)?.last_reminder_on || null, reminders_30d: Number(mLast.get(p.party_id)?.reminders_30d || 0),
      open_promise: mProm.get(p.party_id) ? { promised_date: mProm.get(p.party_id).promised_date, amount: mProm.get(p.party_id).amount } : null,
      risk_score: risk.score, risk_label: risk.label,
    };
  });
  if (bucket && BUCKETS.includes(bucket)) list = list.filter((p) => p[bucket] > 0);
  const sorters = {
    overdue: (x, y) => y.overdue - x.overdue || y.balance - x.balance,
    amount: (x, y) => y.balance - x.balance,
    oldest: (x, y) => y.oldest_days_overdue - x.oldest_days_overdue,
    name: (x, y) => x.name.localeCompare(y.name),
    risk: (x, y) => (y.risk_score ?? -1) - (x.risk_score ?? -1),
  };
  list.sort(sorters[sort] || sorters.overdue);
  return { parties: list, total: list.reduce((s, p) => s + p.balance, 0) };
}

module.exports = { OPEN_INVOICES, BUCKETS, summary, aging, outstandingParties, behaviourByParty };
