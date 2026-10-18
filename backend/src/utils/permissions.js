// Roles and what each may do. Owners can do everything; the others are listed explicitly (deny by default).
const ROLES = ['owner', 'manager', 'cashier', 'accountant', 'viewer'];
const INVITABLE = ROLES.filter((r) => r !== 'owner');

const ALL_VIEW = ['dashboard.view', 'items.view', 'parties.view', 'invoices.view', 'payments.view'];
const PERMISSIONS = {
  owner: ['*'],
  manager: [...ALL_VIEW, 'items.manage', 'items.see_cost', 'parties.manage', 'invoices.create', 'invoices.cancel', 'payments.record',
    'expenses.view', 'expenses.manage', 'reports.view', 'receivables.view', 'reminders.manage', 'inventory.view', 'insights.view'],
  cashier: [...ALL_VIEW, 'parties.manage', 'invoices.create', 'payments.record', 'receivables.view'],
  accountant: [...ALL_VIEW, 'items.see_cost', 'invoices.create', 'payments.record', 'expenses.view', 'expenses.manage', 'reports.view', 'reports.gst',
    'receivables.view', 'reminders.manage', 'backup.export', 'insights.view'],
  viewer: [...ALL_VIEW, 'expenses.view', 'reports.view', 'receivables.view', 'inventory.view', 'insights.view'],
};
// the manager also gets GST reports
PERMISSIONS.manager.push('reports.gst', 'backup.export', 'settings.manage');

const can = (role, perm) => {
  const p = PERMISSIONS[role];
  return !!p && (p.includes('*') || p.includes(perm));
};

/** Express middleware: requirePermission('expenses.manage') or requirePermission({ read: 'expenses.view', write: 'expenses.manage' }). */
function requirePermission(spec) {
  const { forbidden } = require('./errors');
  return (req, _res, next) => {
    const perm = typeof spec === 'string' ? spec : (req.method === 'GET' || req.method === 'HEAD' ? spec.read : spec.write);
    if (!can(req.business && req.business.role, perm)) return next(forbidden(`Your role (${req.business && req.business.role}) is not allowed to do this`));
    next();
  };
}

const COST_KEYS = new Set(['purchase_price', 'stock_value', 'total_value']);
/** Hides purchase prices from roles that may not see them, in any JSON response under the guarded route. */
function maskCost(req, res, next) {
  if (can(req.business && req.business.role, 'items.see_cost')) return next();
  const json = res.json.bind(res);
  const strip = (v) => {
    if (Array.isArray(v)) return v.map(strip);
    if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).filter(([k]) => !COST_KEYS.has(k)).map(([k, x]) => [k, strip(x)]));
    return v;
  };
  res.json = (body) => json(strip(body));
  next();
}

module.exports = { ROLES, INVITABLE, PERMISSIONS, can, requirePermission, maskCost };
