// Recurring invoices: a saved schedule that creates a normal invoice every week / month / quarter / year.
// Runs "on demand" (when the app opens or the owner taps Run now), so it needs no background worker. Each invoice is made
// in its own transaction together with moving the schedule forward, and carries a client_ref, so a double run can never
// bill the same period twice.
const { createInvoice } = require('./invoices');
const { badRequest, notFound } = require('../utils/errors');
const { lockOf } = require('../middleware/bookLock');

const FREQUENCIES = ['weekly', 'monthly', 'quarterly', 'yearly'];
const MAX_CATCH_UP = 12; // after a long break, never create more than this many invoices per schedule in one run

const pad = (n) => String(n).padStart(2, '0');
const fmt = (y, m, d) => `${y}-${pad(m)}-${pad(d)}`;
const daysIn = (y, m) => new Date(Date.UTC(y, m, 0)).getUTCDate();

/** The date after `ymd` for a frequency. Monthly-type steps keep the original day of month where the month is long enough. */
function nextRunDate(ymd, frequency, anchorDay) {
  const [y, m, d] = ymd.split('-').map(Number);
  if (frequency === 'weekly') {
    const x = new Date(Date.UTC(y, m - 1, d + 7));
    return fmt(x.getUTCFullYear(), x.getUTCMonth() + 1, x.getUTCDate());
  }
  const step = frequency === 'monthly' ? 1 : frequency === 'quarterly' ? 3 : 12;
  const total = y * 12 + (m - 1) + step;
  const ny = Math.floor(total / 12), nm = (total % 12) + 1;
  return fmt(ny, nm, Math.min(anchorDay || d, daysIn(ny, nm)));
}

const addDays = (ymd, n) => {
  const x = new Date(`${ymd}T00:00:00Z`);
  x.setUTCDate(x.getUTCDate() + n);
  return x.toISOString().slice(0, 10);
};

const view = (r) => ({
  id: Number(r.id), party_id: Number(r.party_id), party_name: r.party_name, name: r.name, frequency: r.frequency,
  next_date: String(r.next_date).slice(0, 10), end_date: r.end_date ? String(r.end_date).slice(0, 10) : null,
  is_active: r.is_active, last_run_date: r.last_run_date ? String(r.last_run_date).slice(0, 10) : null,
  run_count: r.run_count, last_error: r.last_error, template: r.template,
});

async function list(db, businessId) {
  const { rows } = await db.query(
    `SELECT r.*, p.name AS party_name FROM recurring_invoices r JOIN parties p ON p.id = r.party_id
      WHERE r.business_id = $1 ORDER BY r.is_active DESC, r.next_date, r.id`, [businessId]);
  return rows.map(view);
}

async function create(db, { biz, userId, input }) {
  const { rows: [p] } = await db.query('SELECT id FROM parties WHERE id = $1 AND business_id = $2 AND is_active', [input.party_id, biz.id]);
  if (!p) throw notFound('Party not found');
  if (input.end_date && input.end_date < input.start_date) throw badRequest('End date is before the start date');
  const template = {
    doc_type: input.doc_type, payment_method: input.payment_method, gst_enabled: !!input.gst_enabled && !!biz.gst_registered,
    notes: input.notes || '', terms: input.terms || '', due_days: input.due_days || 0, lines: input.lines,
  };
  const { rows: [r] } = await db.query(
    `INSERT INTO recurring_invoices (business_id, party_id, name, frequency, next_date, end_date, anchor_day, template, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id`,
    [biz.id, input.party_id, input.name, input.frequency, input.start_date, input.end_date || null,
      Number(input.start_date.slice(8, 10)), JSON.stringify(template), userId]);
  return Number(r.id);
}

async function setActive(db, businessId, id, active) {
  const { rowCount } = await db.query(
    `UPDATE recurring_invoices SET is_active = $3, last_error = CASE WHEN $3 THEN '' ELSE last_error END, updated_at = now()
      WHERE id = $1 AND business_id = $2`, [id, businessId, active]);
  if (!rowCount) throw notFound('Schedule not found');
}

async function remove(db, businessId, id) {
  const { rowCount } = await db.query('DELETE FROM recurring_invoices WHERE id = $1 AND business_id = $2', [id, businessId]);
  if (!rowCount) throw notFound('Schedule not found');
}

/**
 * Creates every invoice that is due on or before `today`. `db.tx(fn)` runs fn(client) in a transaction.
 * A schedule whose invoice cannot be made (stock, credit limit, deleted item) stops and shows the reason; others continue.
 */
async function runDue(db, { biz, userId, today }) {
  const created = [];
  const failed = [];
  const lock = lockOf(biz);
  const { rows: due } = await db.query(
    `SELECT id FROM recurring_invoices WHERE business_id = $1 AND is_active AND next_date <= $2::date ORDER BY next_date, id`, [biz.id, today]);

  for (const { id } of due) {
    for (let i = 0; i < MAX_CATCH_UP; i++) {
      let step = null;
      try {
        step = await db.tx(async (c) => {
          const { rows: [r] } = await c.query(
            `SELECT * FROM recurring_invoices WHERE id = $1 AND business_id = $2 AND is_active AND next_date <= $3::date FOR UPDATE SKIP LOCKED`,
            [id, biz.id, today]);
          if (!r) return null;                                               // nothing more due, or another run has it
          const date = String(r.next_date).slice(0, 10);
          const next = nextRunDate(date, r.frequency, r.anchor_day);
          const ended = r.end_date && next > String(r.end_date).slice(0, 10);
          const t = r.template;
          let invoiceId = null;
          if (!(lock && date <= lock)) {                                     // a locked period is skipped, never back-dated
            invoiceId = await createInvoice(c, {
              biz, userId,
              body: {
                doc_type: t.doc_type, party_id: Number(r.party_id), cash_customer: false, invoice_date: date,
                due_date: t.due_days > 0 ? addDays(date, t.due_days) : null,
                payment_method: t.payment_method, gst_enabled: !!t.gst_enabled, notes: t.notes || '', terms: t.terms || '',
                client_ref: `rec${r.id}-${date}`, lines: t.lines,
              },
            });
          }
          await c.query(
            `UPDATE recurring_invoices SET next_date = $2, is_active = $3, last_run_date = $4, run_count = run_count + $5,
                    last_error = '', updated_at = now() WHERE id = $1`,
            [r.id, next, !ended, invoiceId ? date : r.last_run_date, invoiceId ? 1 : 0]);
          return { recurring_id: Number(r.id), invoice_id: invoiceId, date, skipped_locked: !invoiceId };
        });
      } catch (e) {
        await db.query('UPDATE recurring_invoices SET last_error = $2, updated_at = now() WHERE id = $1', [id, String(e.message).slice(0, 300)]);
        failed.push({ recurring_id: Number(id), error: e.message });
        break;
      }
      if (!step) break;
      if (step.invoice_id) created.push(step);
    }
  }
  return { created, failed };
}

module.exports = { FREQUENCIES, nextRunDate, list, create, setActive, remove, runDue };
