// Small pure helpers shared by reminders, receipts and reports.

/** 123456 paise -> "₹1,234.56" (Indian digit grouping: 12,34,567.00). */
function formatINR(paise) {
  const neg = paise < 0;
  const abs = Math.abs(Math.round(paise));
  const rupees = Math.floor(abs / 100);
  const pr = String(abs % 100).padStart(2, '0');
  let s = String(rupees);
  if (s.length > 3) {
    const last3 = s.slice(-3);
    const rest = s.slice(0, -3).replace(/\B(?=(\d{2})+(?!\d))/g, ',');
    s = `${rest},${last3}`;
  }
  return `${neg ? '-' : ''}₹${s}${pr === '00' ? '' : `.${pr}`}`;
}

const MS_DAY = 86400000;
/** Whole days from isoA to isoB (positive when B is later). Both are YYYY-MM-DD. */
function daysBetween(isoA, isoB) {
  return Math.round((Date.parse(`${isoB}T00:00:00Z`) - Date.parse(`${isoA}T00:00:00Z`)) / MS_DAY);
}
function addDays(iso, n) {
  const d = new Date(`${iso}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
/** 2026-10-18 -> 18 Oct 2026 */
function prettyDate(iso) {
  if (!iso) return '';
  const d = new Date(`${String(iso).slice(0, 10)}T00:00:00Z`);
  return d.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', timeZone: 'UTC' });
}

/** Indian mobile -> digits with country code for wa.me, or null when it is not a usable number. */
function normalizePhone(raw) {
  let d = String(raw || '').replace(/\D/g, '');
  if (d.startsWith('00')) d = d.slice(2);
  if (d.length === 11 && d.startsWith('0')) d = d.slice(1);
  if (d.length === 10 && /^[6-9]/.test(d)) return `91${d}`;
  if (d.length === 12 && d.startsWith('91') && /^[6-9]/.test(d[2])) return d;
  return null;
}

const UPI_RE = /^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z][a-zA-Z0-9]{1,63}$/;
const isValidUpiId = (id) => UPI_RE.test(String(id || '').trim());

/** Standard UPI deep link / QR payload. Amount in paise (0 = let the payer type it). */
function buildUpiUrl({ upiId, name, amount = 0, note = '' }) {
  if (!isValidUpiId(upiId)) return null;
  const p = [`pa=${encodeURIComponent(upiId.trim())}`, `pn=${encodeURIComponent(String(name || '').slice(0, 60))}`];
  if (amount > 0) p.push(`am=${(amount / 100).toFixed(2)}`);
  p.push('cu=INR');
  if (note) p.push(`tn=${encodeURIComponent(String(note).slice(0, 80))}`);
  return `upi://pay?${p.join('&')}`;
}

const whatsappUrl = (phone, text) => {
  const n = normalizePhone(phone);
  return n ? `https://wa.me/${n}?text=${encodeURIComponent(text)}` : null;
};
const smsUrl = (phone, text) => {
  const n = normalizePhone(phone);
  return n ? `sms:+${n}?body=${encodeURIComponent(text)}` : null;
};
const mailtoUrl = (email, subject, text) =>
  email ? `mailto:${encodeURIComponent(email)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(text)}` : null;

module.exports = { formatINR, daysBetween, addDays, prettyDate, normalizePhone, isValidUpiId, buildUpiUrl, whatsappUrl, smsUrl, mailtoUrl };
