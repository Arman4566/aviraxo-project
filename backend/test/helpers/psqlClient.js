/**
 * Test-only database client that talks to PostgreSQL through one long-lived `psql` session.
 * It exposes the same `client.query(text, params) -> { rows, rowCount }` shape as `pg`, so the services in
 * src/services can be tested against a real database even where the `pg` package is not installed.
 * (Real servers use `pg`; see src/db.js.)
 */
const { spawn } = require('node:child_process');

const END = '__END__';

function literal(v) {
  if (v === null || v === undefined) return 'NULL';
  if (typeof v === 'number') return Number.isFinite(v) ? `(${v})` : 'NULL';
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (Array.isArray(v)) return `ARRAY[${v.map(literal).join(',')}]`;
  if (typeof v === 'object') return `'${JSON.stringify(v).replace(/'/g, "''")}'`;
  return `'${String(v).replace(/'/g, "''")}'`;
}

function bind(text, params = []) {
  return text.replace(/\$(\d+)/g, (_, n) => {
    const i = Number(n) - 1;
    if (i >= params.length) throw new Error(`Missing parameter $${n}`);
    return literal(params[i]);
  });
}

function wrap(sql) {
  const t = sql.trim();
  if (/^(BEGIN|COMMIT|ROLLBACK)\b/i.test(t)) return { sql: t, raw: true };
  if (/^(INSERT|UPDATE|DELETE)\b/i.test(t)) {
    const body = /\bRETURNING\b/i.test(t) ? t : `${t} RETURNING 1`;
    return { sql: `WITH t AS (${body}) SELECT coalesce(json_agg(t), '[]'::json) FROM t`, raw: false };
  }
  return { sql: `SELECT coalesce(json_agg(t), '[]'::json) FROM (${t}) t`, raw: false };
}

class PsqlSession {
  constructor(db, { command = 'psql', args = [] } = {}) {
    this.proc = spawn(command, [...args, '-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=0', '-v', 'VERBOSITY=verbose', db], { stdio: ['pipe', 'pipe', 'pipe'] });
    this.out = '';
    this.err = '';
    this.waiter = null;
    this.proc.stdout.on('data', (d) => { this.out += d; this._check(); });
    this.proc.stderr.on('data', (d) => { this.err += d; this._check(); });
    this.queue = Promise.resolve();
  }

  _check() {
    if (this.waiter && this.out.includes(END) && this.err.includes(END)) {
      const w = this.waiter;
      this.waiter = null;
      const out = this.out.slice(0, this.out.indexOf(END)).trim();
      const err = this.err.slice(0, this.err.indexOf(END)).trim();
      this.out = '';
      this.err = '';
      w({ out, err });
    }
  }

  run(sql) {
    const job = this.queue.then(() => new Promise((resolve) => {
      this.waiter = resolve;
      this.proc.stdin.write(`${sql};\n\\echo ${END}\n\\warn ${END}\n`);
    }));
    this.queue = job.catch(() => {});
    return job;
  }

  async query(text, params) {
    const w = wrap(bind(text, params));
    const { out, err } = await this.run(w.sql);
    const errLine = err.split('\n').find((l) => /^ERROR:/.test(l));
    if (errLine) {
      const e = new Error(errLine.replace(/^ERROR:\s*/, ''));
      e.code = (/^ERROR:\s+([0-9A-Z]{5}):/.exec(errLine) || [])[1];
      throw e;
    }
    if (w.raw || !out) return { rows: [], rowCount: 0 };
    const rows = JSON.parse(out);
    return { rows, rowCount: rows.length };
  }

  close() { this.proc.stdin.end(); }
}

/** Same contract as src/db.js withTransaction, on a PsqlSession. */
async function withTransaction(session, fn) {
  await session.query('BEGIN');
  try {
    const r = await fn(session);
    await session.query('COMMIT');
    return r;
  } catch (e) {
    await session.query('ROLLBACK');
    throw e;
  }
}

module.exports = { PsqlSession, withTransaction, bind, literal };
