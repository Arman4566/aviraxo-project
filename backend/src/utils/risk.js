// Payment-risk score from a customer's own history. Pure maths, explainable, no external AI service.
const clamp = (n, lo, hi) => Math.min(hi, Math.max(lo, n));

/**
 * stats: {
 *   paid_amount        paise settled so far against invoices that had a due date
 *   on_time_amount     part of paid_amount settled within `graceDays` of the due date
 *   weighted_days_late sum(days_late * amount) (negative = early); divide by paid_amount for the average
 *   overdue_amount     what is overdue right now
 *   outstanding_amount everything currently unpaid
 *   max_days_overdue   oldest overdue invoice, in days
 * }
 * Returns { score: 0..100 (higher = riskier) | null, label: 'low'|'medium'|'high'|'new', reasons: [] }
 */
function riskScore(stats) {
  const paid = stats.paid_amount || 0;
  const outstanding = stats.outstanding_amount || 0;
  const overdue = stats.overdue_amount || 0;
  if (paid === 0 && overdue === 0) {
    return { score: null, label: 'new', on_time_rate: null, avg_days_late: null, reasons: ['No payment history yet'] };
  }
  const reasons = [];
  const onTimeRate = paid > 0 ? stats.on_time_amount / paid : 1;
  const avgLate = paid > 0 ? stats.weighted_days_late / paid : 0;
  const overdueShare = outstanding > 0 ? overdue / outstanding : 0;
  const oldest = stats.max_days_overdue || 0;

  const score = Math.round(clamp(
    100 * (0.4 * (1 - onTimeRate) + 0.25 * clamp(avgLate, 0, 60) / 60 + 0.2 * overdueShare + 0.15 * clamp(oldest, 0, 90) / 90), 0, 100));

  if (paid > 0) reasons.push(`${Math.round(onTimeRate * 100)}% of past payments were on time`);
  if (paid > 0 && avgLate > 1) reasons.push(`pays about ${Math.round(avgLate)} days late on average`);
  if (overdue > 0) reasons.push(`${Math.round(overdueShare * 100)}% of the balance is overdue`);
  if (oldest > 30) reasons.push(`oldest unpaid invoice is ${oldest} days overdue`);
  return { score, label: score < 25 ? 'low' : score < 55 ? 'medium' : 'high', on_time_rate: Math.round(onTimeRate * 100) / 100, avg_days_late: Math.round(avgLate * 10) / 10, reasons };
}

/** Chance (0..1) a customer pays an invoice on time, used by the cash-flow forecast. */
function onTimeProbability(risk) {
  if (risk.score === null) return 0.7;          // new customer: assume most pay
  return clamp(1 - risk.score / 100 * 0.9, 0.1, 0.98);
}

module.exports = { riskScore, onTimeProbability };
