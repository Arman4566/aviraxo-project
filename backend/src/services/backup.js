// Full-business backup (JSON) and restore into an EMPTY business. Every function takes a db client.
const { badRequest, conflict } = require('../utils/errors');
const { audit } = require('../utils/audit');

const VERSION = 1;
// Tables in dependency order. `fk` maps a column to the table whose (old) id it points at.
const TABLES = [
  { key: 'parties', table: 'parties', fk: {} },
  { key: 'items', table: 'items', fk: {} },
  { key: 'expenses', table: 'expenses', fk: { party_id: 'parties' } },
  { key: 'invoices', table: 'invoices', fk: { party_id: 'parties', converted_to: null, converted_from: null } },
  { key: 'invoice_lines', table: 'invoice_lines', fk: { invoice_id: 'invoices', item_id: 'items' }, noBusiness: true },
  { key: 'stock_movements', table: 'stock_movements', fk: { item_id: 'items' } },
  { key: 'payments', table: 'payments', fk: { party_id: 'parties' } },
  { key: 'payment_allocations', table: 'payment_allocations', fk: { payment_id: 'payments', invoice_id: 'invoices' }, noBusiness: true },
  { key: 'reminder_rules', table: 'reminder_rules', fk: {} },
  { key: 'reminder_log', table: 'reminder_log', fk: { party_id: 'parties', invoice_id: 'invoices', rule_id: 'reminder_rules' } },
  { key: 'payment_promises', table: 'payment_promises', fk: { party_id: 'parties', invoice_id: 'invoices' } },
];

async function exportAll(db, business) {
  const out = { app: 'aviraxo', version: VERSION, exported_at: new Date().toISOString(), business: { name: business.name, gstin: business.gstin, settings: business.settings || {} } };
  for (const t of TABLES) {
    const sql = t.noBusiness
      ? t.table === 'invoice_lines'
        ? 'SELECT l.* FROM invoice_lines l JOIN invoices i ON i.id = l.invoice_id WHERE i.business_id = $1 ORDER BY l.id'
        : 'SELECT a.* FROM payment_allocations a JOIN payments p ON p.id = a.payment_id WHERE p.business_id = $1 ORDER BY a.id'
      : `SELECT * FROM ${t.table} WHERE business_id = $1 ORDER BY id`;
    const { rows } = await db.query(sql, [business.id]);
    out[t.key] = rows;
  }
  const { rows: seq } = await db.query('SELECT series, last_number FROM document_sequences WHERE business_id = $1', [business.id]);
  out.document_sequences = seq;
  out.counts = Object.fromEntries(TABLES.map((t) => [t.key, out[t.key].length]));
  return out;
}

async function isEmpty(db, businessId) {
  const { rows: [r] } = await db.query(
    `SELECT (SELECT COUNT(*) FROM parties WHERE business_id = $1) + (SELECT COUNT(*) FROM items WHERE business_id = $1)
          + (SELECT COUNT(*) FROM invoices WHERE business_id = $1) + (SELECT COUNT(*) FROM payments WHERE business_id = $1)
          + (SELECT COUNT(*) FROM expenses WHERE business_id = $1) AS n`, [businessId]);
  return Number(r.n) === 0;
}

const colCache = new Map();
async function columnsOf(db, table) {
  if (!colCache.has(table)) {
    const { rows } = await db.query(`SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = $1`, [table]);
    colCache.set(table, new Set(rows.map((r) => r.column_name)));
  }
  return colCache.get(table);
}

/**
 * Restores a backup made by exportAll into a business that has no data yet. Ids are remapped, document numbers and
 * dates are kept exactly as they were. Runs in the caller's transaction, so a bad file changes nothing.
 */
async function restore(c, { biz, userId, data }) {
  if (!data || data.app !== 'aviraxo' || data.version !== VERSION) throw badRequest('This is not a Galla Pro backup file');
  if (!(await isEmpty(c, biz.id))) throw conflict('Restore is only allowed into a business with no data yet. Create a new firm and restore there.');

  const idMap = Object.fromEntries(TABLES.map((t) => [t.table, new Map()]));
  const deferred = [];
  for (const t of TABLES) {
    const cols = await columnsOf(c, t.table);
    for (const row of data[t.key] || []) {
      const vals = {};
      for (const [k, v] of Object.entries(row)) {
        if (k === 'id' || !cols.has(k)) continue;
        vals[k] = v;
      }
      if (cols.has('business_id')) vals.business_id = biz.id;
      if (cols.has('created_by')) vals.created_by = userId;
      for (const [col, ref] of Object.entries(t.fk)) {
        if (vals[col] === null || vals[col] === undefined) continue;
        if (ref === null) { deferred.push({ table: t.table, oldId: row.id, col, old: vals[col] }); delete vals[col]; continue; }
        const mapped = idMap[ref].get(vals[col]);
        if (mapped === undefined) throw badRequest(`Backup is inconsistent: ${t.table}.${col} points to a missing record`);
        vals[col] = mapped;
      }
      if (t.table === 'stock_movements' && vals.ref_id != null) {           // ref_id points at an invoice or an item
        const m = idMap[vals.ref_type === 'invoice' ? 'invoices' : 'items'].get(vals.ref_id);
        if (m === undefined) throw badRequest('Backup is inconsistent: stock_movements.ref_id points to a missing record');
        vals.ref_id = m;
      }
      const keys = Object.keys(vals);
      const { rows } = await c.query(
        `INSERT INTO ${t.table} (${keys.join(',')}) VALUES (${keys.map((_, i) => `$${i + 1}`).join(',')}) RETURNING id`, keys.map((k) => vals[k]));
      idMap[t.table].set(row.id, rows[0].id);
    }
  }
  for (const d of deferred) {                    // invoice -> invoice links are fixed once every invoice exists
    const to = idMap.invoices.get(d.old);
    if (to !== undefined) await c.query(`UPDATE invoices SET ${d.col} = $2 WHERE id = $1`, [idMap.invoices.get(d.oldId), to]);
  }
  for (const s of data.document_sequences || []) {
    await c.query(
      `INSERT INTO document_sequences (business_id, series, last_number) VALUES ($1,$2,$3)
       ON CONFLICT (business_id, series) DO UPDATE SET last_number = GREATEST(document_sequences.last_number, EXCLUDED.last_number)`, [biz.id, s.series, s.last_number]);
  }
  await audit(c, { businessId: biz.id, userId, entity: 'backup', entityId: null, action: 'restore', details: data.counts || {} });
  return { restored: Object.fromEntries(TABLES.map((t) => [t.key, idMap[t.table].size])) };
}

module.exports = { VERSION, exportAll, restore, isEmpty };
