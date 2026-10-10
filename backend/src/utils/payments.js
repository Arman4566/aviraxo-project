// The app sends payment methods as display text ('Cash', 'UPI', 'Bank Transfer', 'Credit (Pay Later)'...).
const MODES = ['cash', 'upi', 'card', 'bank', 'cheque', 'other'];

function normalizeMode(input) {
  const s = String(input || '').trim().toLowerCase();
  if (MODES.includes(s)) return s;
  if (s.startsWith('bank')) return 'bank';
  if (s.startsWith('cheque') || s.startsWith('check')) return 'cheque';
  return 'other';
}

/** 'Credit' / 'Credit (Pay Later)' means the customer pays later. */
const isCreditMethod = (input) => String(input || '').trim().toLowerCase().startsWith('credit');

/** 'Net 15' -> 15, 'Immediate' -> 0 */
function termDays(term) {
  const m = /(\d+)/.exec(String(term || ''));
  return m ? Number(m[1]) : 0;
}

module.exports = { MODES, normalizeMode, isCreditMethod, termDays };
