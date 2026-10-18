// Applies db/schema.sql then db/phase2.sql. Safe to run repeatedly (all statements are IF NOT EXISTS).
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
    for (const file of ['schema.sql', 'phase2.sql']) {
      await pool.query(fs.readFileSync(path.join(__dirname, file), 'utf8'));
      console.log(`Applied ${file}`);
    }
    console.log('Schema applied.');
  } catch (e) {
    console.error('Migration failed:', e.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
})();
