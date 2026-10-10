const { Pool, types } = require('pg');
const config = require('./config');

// BIGINT (paise, ids, counts) arrives as string by default. Values stay far below 2^53, so parse to number.
types.setTypeParser(20, (v) => parseInt(v, 10));
// NUMERIC (quantities, rates, SUM of numeric) -> number.
types.setTypeParser(1700, (v) => parseFloat(v));
// DATE -> 'YYYY-MM-DD' string (avoids timezone shifts).
types.setTypeParser(1082, (v) => v);

// Neon (and most hosted Postgres) requires TLS. Local Postgres usually has none, so only enable it when asked for.
const needsSsl = /sslmode=require|neon\.tech/i.test(config.databaseUrl);
const pool = new Pool({
  connectionString: config.databaseUrl,
  ssl: needsSsl ? { rejectUnauthorized: false } : undefined,
  max: 5,
});

/** Runs fn(client) inside a transaction; commits on success, rolls back on any throw. */
async function withTransaction(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (e) {
    try { await client.query('ROLLBACK'); } catch { /* connection already broken */ }
    throw e;
  } finally {
    client.release();
  }
}

module.exports = { pool, withTransaction, query: (t, p) => pool.query(t, p) };
