const router = require('express').Router();
const { z } = require('zod');
const { query } = require('../db');
const validate = require('../middleware/validate');
const asyncHandler = require('../utils/asyncHandler');
const { badRequest } = require('../utils/errors');
const { can } = require('../utils/permissions');
const { todayIST } = require('../utils/time');
const { addDays, daysBetween } = require('../utils/format');
const svc = require('../services/analytics');

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD');
const preset = { '7d': 7, '30d': 30, '90d': 90, '365d': 365 };

// One call powers the whole analytics screen: KPIs vs previous period, trend, top items/customers, payment modes, expense split, 6-month view.
router.get('/overview', validate(z.object({ from: isoDate.optional(), to: isoDate.optional(), range: z.enum(['7d', '30d', '90d', '365d']).optional() }), 'query'),
  asyncHandler(async (req, res) => {
    const to = req.query.to || todayIST();
    const from = req.query.from || addDays(to, -((preset[req.query.range] || 30) - 1));
    if (from > to) throw badRequest('"from" must not be after "to"');
    if (daysBetween(from, to) > 400) throw badRequest('Pick a period of 400 days or less');
    const out = await svc.overview({ query }, req.business.id, { from, to });
    // Profit needs purchase prices; roles that may not see cost must not be able to back-calculate it.
    if (!can(req.business.role, 'items.see_cost')) {
      for (const t of [out.totals, out.previous_totals]) { delete t.gross_profit; delete t.net_profit; delete t.margin_pct; }
      delete out.change_pct.net_profit;
      out.monthly = out.monthly.map(({ profit_estimate, ...m }) => m);
    }
    res.json(out);
  }));

module.exports = router;
