const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { requireAuth, requireBusiness } = require('./middleware/auth');
const errorHandler = require('./middleware/error');
const { notFound } = require('./utils/errors');

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// Signed-in routes (valid Firebase ID token). A business is not required yet.
app.use('/api/me', requireAuth, require('./routes/me'));
app.use('/api/business', requireAuth, (req, res, next) => (req.method === 'PUT' ? next() : requireBusiness(req, res, next)), require('./routes/business'));

// Everything below is tenant-scoped: token + the user's business.
const tenant = [requireAuth, requireBusiness];
app.use('/api/items', tenant, require('./routes/items'));
app.use('/api/parties', tenant, require('./routes/parties'));
app.use('/api/invoices', tenant, require('./routes/invoices'));
app.use('/api/payments', tenant, require('./routes/payments'));
app.use('/api/dashboard', tenant, require('./routes/dashboard'));
app.use('/api/reports', tenant, require('./routes/reports'));

app.use((_req, _res, next) => next(notFound('Route not found')));
app.use(errorHandler);

module.exports = app;
