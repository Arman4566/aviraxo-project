const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const { requireAuth, requireBusiness } = require('./middleware/auth');
const errorHandler = require('./middleware/error');
const { notFound } = require('./utils/errors');
const { requirePermission, maskCost } = require('./utils/permissions');

const app = express();
app.use(helmet());
app.use(cors());
// Bill photos are bigger than normal requests; this parser runs first for that one route only.
app.use('/api/ai/scan-bill', express.json({ limit: '8mb' }));
app.use(express.json({ limit: '1mb' }));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// Signed-in routes (valid Firebase ID token). A business is not required yet.
app.use('/api/me', requireAuth, require('./routes/me'));
app.use('/api/business', requireAuth, (req, res, next) => (req.method === 'PUT' ? next() : requireBusiness(req, res, next)), require('./routes/business'));

// Everything below is tenant-scoped: token + the user's business, then a role check per area (deny by default).
const tenant = [requireAuth, requireBusiness];
const guard = (spec, ...more) => [...tenant, requirePermission(spec), ...more];
app.use('/api/items', guard({ read: 'items.view', write: 'items.manage' }, maskCost), require('./routes/items'));
app.use('/api/parties', guard({ read: 'parties.view', write: 'parties.manage' }), require('./routes/parties'));
app.use('/api/invoices', guard({ read: 'invoices.view', write: 'invoices.create' }), require('./routes/invoices'));
app.use('/api/payments', guard({ read: 'payments.view', write: 'payments.record' }), require('./routes/payments'));
app.use('/api/dashboard', guard('dashboard.view'), require('./routes/dashboard'));
app.use('/api/reports', guard('reports.view', maskCost), require('./routes/reports'));
app.use('/api/receivables', guard({ read: 'receivables.view', write: 'reminders.manage' }), require('./routes/receivables'));
app.use('/api/reminders', guard({ read: 'receivables.view', write: 'reminders.manage' }), require('./routes/reminders'));
app.use('/api/promises', guard({ read: 'receivables.view', write: 'reminders.manage' }), require('./routes/promises'));
app.use('/api/expenses', guard({ read: 'expenses.view', write: 'expenses.manage' }), require('./routes/expenses'));
app.use('/api/inventory', guard('items.view', maskCost), require('./routes/inventory'));
app.use('/api/analytics', guard('reports.view'), require('./routes/analytics'));
app.use('/api/ai', guard('insights.view'), require('./routes/ai'));
app.use('/api/insights', guard('insights.view'), require('./routes/insights'));
app.use('/api/backup', guard('backup.export'), require('./routes/backup'));
app.use('/api/staff', guard('staff.manage'), require('./routes/staff'));

app.use((_req, _res, next) => next(notFound('Route not found')));
app.use(errorHandler);

module.exports = app;
