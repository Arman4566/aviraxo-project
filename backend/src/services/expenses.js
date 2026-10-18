// Expense tracking and other income. Every function takes a db client (see receivables.js).
const { notFound, badRequest } = require('../utils/errors');
const { todayIST } = require('../utils/time');
const { addDays } = require('../utils/format');
const { normalizeMode } = require('../utils/payments');

const addMonths = (iso, n) => {
  const [y, m, d] = iso.split('-').map(Number);
  const last = new Date(Date.UTC(y, m - 1 + n + 1, 0)).getUTCDate();       // clamp 31 Jan + 1 month -> 28/29 Feb
  return new Date(Date.UTC(y, m - 1 + n, Math.min(d, last))).toISOString().slice(0, 10);
};
const nextDue = (iso, every) => (every === 'weekly' ? addDays(iso, 7) : every === 'monthly' ? addMonths(iso, 1) : addMonths(iso, 12));

/** Starter categories for the picker; the owner can also type any new one. */
const DEFAULT_CATEGORIES = ['Rent', 'Salary', 'Electricity', 'Transport', 'Internet & Phone', 'Packaging', 'Repairs & Maintenance',
  'Marketing', 'Office Supplies', 'Tea & Food', 'Fuel', 'Bank Charges', 'Insurance', 'Taxes & Fees', 'Miscellaneous'];

async function createExpense(db, { businessId, userId, body: b }) {
  if (b.client_ref) {
    const { rows: dup } = await db.query('SELECT * FROM expenses WHERE business_id = $1 AND client_ref = $2', [businessId, b.client_ref]);
    if (dup[0]) return dup[0];
  }
  if ((b.gst_amount || 0) > b.amount) throw badRequest('GST cannot be more than the total amount');
  if (b.party_id) {
    const { rows: [p] } = await db.query('SELECT id FROM parties WHERE id = $1 AND business_id = $2', [b.party_id, businessId]);
    if (!p) throw notFound('Party not found');
  }
  const date = b.entry_date || todayIST();
  const { rows } = await db.query(
    `INSERT INTO expenses (business_id, kind, category, amount, gst_amount, mode, entry_date, party_id, note, receipt_url, recurring, next_due, client_ref, created_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) RETURNING *`,
    [businessId, b.kind || 'expense', b.category.trim(), b.amount, b.gst_amount || 0, normalizeMode(b.mode || 'cash'), date, b.party_id || null,
     b.note || '', b.receipt_url || '', b.recurring || null, b.recurring ? nextDue(date, b.recurring) : null, b.client_ref || null, userId]);
  return rows[0];
}

async function updateExpense(db, businessId, id, patch) {
  const { rows: [cur] } = await db.query('SELECT * FROM expenses WHERE id = $1 AND business_id = $2 FOR UPDATE', [id, businessId]);
  if (!cur) throw notFound('Entry not found');
  const n = { ...cur, ...patch };
  if (n.gst_amount > n.amount) throw badRequest('GST cannot be more than the total amount');
  const recurringChanged = patch.recurring !== undefined || patch.entry_date !== undefined;
  const due = recurringChanged ? (n.recurring ? nextDue(String(n.entry_date).slice(0, 10), n.recurring) : null) : cur.next_due;
  const { rows } = await db.query(
    `UPDATE expenses SET kind=$3, category=$4, amount=$5, gst_amount=$6, mode=$7, entry_date=$8, note=$9, receipt_url=$10, recurring=$11, next_due=$12, updated_at=now()
      WHERE id=$1 AND business_id=$2 RETURNING *`,
    [id, businessId, n.kind, n.category, n.amount, n.gst_amount, patch.mode ? normalizeMode(patch.mode) : n.mode, n.entry_date, n.note, n.receipt_url, n.recurring || null, due]);
  return rows[0];
}

async function deleteExpense(db, businessId, id) {
  const { rows } = await db.query('DELETE FROM expenses WHERE id = $1 AND business_id = $2 RETURNING id', [id, businessId]);
  if (!rows[0]) throw notFound('Entry not found');
}

async function listExpenses(db, businessId, { from, to, kind, category, limit = 500, offset = 0 } = {}) {
  const params = [businessId];
  const where = ['e.business_id = $1'];
  if (from) { params.push(from); where.push(`e.entry_date >= $${params.length}`); }
  if (to) { params.push(to); where.push(`e.entry_date <= $${params.length}`); }
  if (kind) { params.push(kind); where.push(`e.kind = $${params.length}`); }
  if (category) { params.push(category); where.push(`lower(e.category) = lower($${params.length})`); }
  params.push(limit, offset);
  const { rows } = await db.query(
    `SELECT e.*, p.name AS party_name FROM expenses e LEFT JOIN parties p ON p.id = e.party_id
      WHERE ${where.join(' AND ')} ORDER BY e.entry_date DESC, e.id DESC LIMIT $${params.length - 1} OFFSET $${params.length}`, params);
  return rows;
}

/**
 * Creates the entries that fell due for recurring expenses (rent every month, etc).
 * Each template keeps its own next_due, so running this twice on the same day never duplicates anything.
 */
async function runRecurring(db, businessId, today = todayIST()) {
  const { rows } = await db.query(
    `SELECT * FROM expenses WHERE business_id = $1 AND recurring IS NOT NULL AND next_due IS NOT NULL AND next_due <= $2 ORDER BY id FOR UPDATE`, [businessId, today]);
  let created = 0;
  for (const t of rows) {
    let due = String(t.next_due).slice(0, 10);
    let guard = 0;
    while (due <= today && guard++ < 24) {
      await db.query(
        `INSERT INTO expenses (business_id, kind, category, amount, gst_amount, mode, entry_date, party_id, note, created_by)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
        [businessId, t.kind, t.category, t.amount, t.gst_amount, t.mode, due, t.party_id, t.note ? `${t.note} (recurring)` : 'Recurring', t.created_by]);
      created += 1;
      due = nextDue(due, t.recurring);
    }
    await db.query('UPDATE expenses SET next_due = $2 WHERE id = $1', [t.id, due]);
  }
  return { created };
}

async function summary(db, businessId, { from, to }) {
  const { rows: byCat } = await db.query(
    `SELECT kind, category, SUM(amount) AS total, SUM(gst_amount) AS gst, COUNT(*) AS entries FROM expenses
      WHERE business_id = $1 AND entry_date BETWEEN $2 AND $3 GROUP BY kind, category ORDER BY kind, total DESC`, [businessId, from, to]);
  const { rows: byMonth } = await db.query(
    `SELECT to_char(date_trunc('month', entry_date), 'YYYY-MM') AS month,
            COALESCE(SUM(amount) FILTER (WHERE kind = 'expense'), 0) AS expense,
            COALESCE(SUM(amount) FILTER (WHERE kind = 'income'), 0) AS income
       FROM expenses WHERE business_id = $1 AND entry_date BETWEEN $2 AND $3 GROUP BY 1 ORDER BY 1`, [businessId, from, to]);
  const sum = (kind, k = 'total') => byCat.filter((r) => r.kind === kind).reduce((s, r) => s + Number(r[k]), 0);
  return {
    from, to,
    total_expense: sum('expense'), total_income: sum('income'), input_gst: sum('expense', 'gst'),
    by_category: byCat.map((r) => ({ kind: r.kind, category: r.category, total: Number(r.total), gst: Number(r.gst), entries: Number(r.entries) })),
    by_month: byMonth.map((r) => ({ month: r.month, expense: Number(r.expense), income: Number(r.income) })),
  };
}

async function categories(db, businessId) {
  const { rows } = await db.query(`SELECT DISTINCT category FROM expenses WHERE business_id = $1 ORDER BY category`, [businessId]);
  const used = rows.map((r) => r.category);
  return [...used, ...DEFAULT_CATEGORIES.filter((c) => !used.some((u) => u.toLowerCase() === c.toLowerCase()))];
}

module.exports = { DEFAULT_CATEGORIES, nextDue, addMonths, createExpense, updateExpense, deleteExpense, listExpenses, runRecurring, summary, categories };
