const app = require('./app');
const config = require('./config');
const { pool } = require('./db');

if (config.devAuth) console.warn('WARNING: DEV_AUTH is on. Tokens like "dev:name" are accepted. Never enable this in production.');

const server = app.listen(config.port, () => console.log(`Galla Pro API listening on :${config.port}`));

const shutdown = () => server.close(() => pool.end().then(() => process.exit(0)));
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
