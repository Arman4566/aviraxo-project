// Applies db/schema.sql. Safe to run repeatedly (all statements are IF NOT EXISTS).
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

(async () => {
  const url = process.env.DATABASE_URL || '';
  const pool = new Pool({
    connectionString: url,
    ssl: /sslmode=require|neon\.tech/i.test(url) ? { rejectUnauthorized: false } : undefined,
  });
  try {
    const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
    await pool.query(sql);
    console.log('Schema applied.');
  } catch (e) {
    console.error('Migration failed:', e.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
})();
