const express = require('express');
const helmet = require('helmet');
const { requireAuth, requireBusiness } = require('./middleware/auth');
const errorHandler = require('./middleware/error');
const { bookLock } = require('./middleware/bookLock');
const { notFound } = require('./utils/errors');
const { requirePermission, maskCost } = require('./utils/permissions');
const config = require('./config');
const { rateLimit, corsAllowList, apiHeaders } = require('./middleware/security');

const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 1);                      // behind Render's proxy: use the real client address for rate limits
app.use(helmet());
app.use(corsAllowList(config.corsOrigins));     // no browser origin is allowed unless listed in CORS_ORIGINS
app.use('/api', apiHeaders);

// Abuse limits. General per client address; a tighter one for requests with no login token at all.
app.use('/api', rateLimit({ windowMs: 60_000, max: config.rateLimitPerMin }));
const anonLimit = rateLimit({ windowMs: 60_000, max: config.authFailLimit, message: 'Too many requests without a valid login.' });
app.use('/api', (req, res, next) => ((req.headers.authorization || '').startsWith('Bearer ') ? next() : anonLimit(req, res, next)));
// Expensive endpoints (AI, exports, backup) are limited per signed-in user, not just per address.
const heavy = rateLimit({ windowMs: 60_000, max: config.heavyLimitPerMin, key: (req) => `u:${req.user ? req.user.id : req.ip}` });

// Bill photos and files are bigger than normal requests. The caller is verified BEFORE the large body is read,
// so an anonymous client cannot make the server buffer 12 MB.
app.use(['/api/ai/scan-bill', '/api/ai/import-file'], requireAuth, requireBusiness, heavy, express.json({ limit: '12mb' }));
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
app.use('/api/invoices', guard({ read: 'invoices.view', write: 'invoices.create' }, bookLock('invoices')), require('./routes/invoices'));
app.use('/api/payments', guard({ read: 'payments.view', write: 'payments.record' }, bookLock('payments')), require('./routes/payments'));
app.use('/api/dashboard', guard('dashboard.view'), require('./routes/dashboard'));
app.use('/api/reports/export', requireAuth, requireBusiness, heavy);
app.use('/api/reports', guard('reports.view', maskCost), require('./routes/reports'));
app.use('/api/receivables', guard({ read: 'receivables.view', write: 'reminders.manage' }), require('./routes/receivables'));
app.use('/api/reminders', guard({ read: 'receivables.view', write: 'reminders.manage' }), require('./routes/reminders'));
app.use('/api/promises', guard({ read: 'receivables.view', write: 'reminders.manage' }), require('./routes/promises'));
app.use('/api/expenses', guard({ read: 'expenses.view', write: 'expenses.manage' }, bookLock('expenses')), require('./routes/expenses'));
app.use('/api/recurring', guard({ read: 'invoices.view', write: 'invoices.create' }), require('./routes/recurring'));
app.use('/api/inventory', guard('items.view', maskCost), require('./routes/inventory'));
app.use('/api/analytics', guard('reports.view'), require('./routes/analytics'));
app.use('/api/ai', guard('insights.view', heavy), require('./routes/ai'));
app.use('/api/insights', guard('insights.view'), require('./routes/insights'));
app.use('/api/backup', guard('backup.export', heavy), require('./routes/backup'));
app.use('/api/staff', guard('staff.manage'), require('./routes/staff'));

app.use((_req, _res, next) => next(notFound('Route not found')));
app.use(errorHandler);

module.exports = app;
