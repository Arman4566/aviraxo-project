// Books lock (like "lock period" in accounting software): once the owner sets settings.booksLockedUntil = 'YYYY-MM-DD',
// invoices, payments and expenses dated on or before that day can no longer be created, changed or cancelled, so
// reports already filed (GST, accountant) never shift. Reads are never blocked.
const { todayIST } = require('../utils/time');
const { forbidden } = require('../utils/errors');

const ISO = /^\d{4}-\d{2}-\d{2}$/;
const lockOf = (business) => {
  const v = business && business.settings && business.settings.booksLockedUntil;
  return typeof v === 'string' && ISO.test(v) ? v : null;
};

/**
 * kind: 'invoices' | 'payments' | 'expenses'. Returns middleware that rejects write requests whose date is locked.
 * `lookup` is injectable for tests.
 */
function bookLock(kind, { lookup } = {}) {
  return async function bookLockMiddleware(req, _res, next) {
    try {
      if (req.method === 'GET' || req.method === 'HEAD' || req.method === 'OPTIONS') return next();
      const q = (...a) => (lookup || require('../db').query)(...a); // loaded lazily so unit tests need no database driver
      const lock = lockOf(req.business);
      if (!lock) return next();

      const dates = [];
      const body = req.body || {};
      const idMatch = /^\/(\d+)(?:\/|$)/.exec(req.path);
      if (kind === 'invoices') {
        if (req.method === 'POST' && req.path === '/') dates.push(body.invoice_date || todayIST());
        else if (idMatch && /\/convert$/.test(req.path)) dates.push(body.invoice_date || todayIST());
        if (idMatch && /\/cancel$/.test(req.path)) {
          const { rows } = await q('SELECT invoice_date::text AS d FROM invoices WHERE id = $1 AND business_id = $2', [Number(idMatch[1]), req.business.id]);
          if (rows[0]) dates.push(rows[0].d.slice(0, 10));
        }
      } else if (kind === 'payments') {
        if (req.method === 'POST') dates.push(body.payment_date || todayIST());
      } else if (kind === 'expenses') {
        if (req.method === 'POST') dates.push(body.entry_date || todayIST());
        if (idMatch && (req.method === 'PUT' || req.method === 'DELETE')) {
          const { rows } = await q('SELECT entry_date::text AS d FROM expenses WHERE id = $1 AND business_id = $2', [Number(idMatch[1]), req.business.id]);
          if (rows[0]) dates.push(rows[0].d.slice(0, 10));
          if (body.entry_date) dates.push(body.entry_date);
        }
      }
      if (dates.some((d) => d <= lock)) {
        throw forbidden(`Books are locked up to ${lock}. Change the lock date in Settings to edit entries on or before that day.`);
      }
      next();
    } catch (e) {
      next(e);
    }
  };
}

module.exports = { bookLock, lockOf };
