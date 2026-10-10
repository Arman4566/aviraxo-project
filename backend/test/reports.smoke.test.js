// Executes the dashboard/report SQL against PostgreSQL. express/zod/pg are stubbed so this runs without npm install.
//   TEST_DB=aviraxo_it npm test
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { PsqlSession } = require('./helpers/psqlClient');
const DB = process.env.TEST_DB;

test('dashboard and report queries execute', { skip: DB ? false : 'set TEST_DB' }, async () => {
  const s = new PsqlSession(DB);
  const src = (p) => path.resolve(__dirname, '../src', p);
  const stub = (id, exp) => { require.cache[id] = { id, filename: id, loaded: true, exports: exp }; };
  const handlers = {};
  let cur = null;
  const router = new Proxy({}, { get: (_, verb) => (route, ...fns) => { handlers[`${cur}${route}`] = fns[fns.length - 1]; } });
  const chain = () => new Proxy(function () {}, { get: () => chain(), apply: () => chain() });
  stub(require.resolve('node:path'), require('node:path'));
  const Module = require('node:module');
  const orig = Module._resolveFilename;
  Module._resolveFilename = function (r, ...a) {
    if (r === 'express') return 'express-stub';
    if (r === 'zod') return 'zod-stub';
    return orig.call(this, r, ...a);
  };
  stub('express-stub', { Router: () => router });
  stub('zod-stub', { z: chain() });
  stub(src('db.js'), { query: (t, p) => s.query(t, p) });
  const load = (name) => { cur = name; delete require.cache[src(`routes/${name}.js`)]; require(src(`routes/${name}.js`)); };
  load('dashboard'); load('reports');
  Module._resolveFilename = orig;

  const b = { id: '00000000-0000-0000-0000-000000000000' }; // an unknown business id is enough to prove every statement executes
  const call = async (key, req) => { let out; await handlers[key]({ business: { id: b.id }, query: {}, ...req }, { json: (v) => { out = v; } }, (e) => { throw e; }); return out; };

  try {
  const d = await call('dashboard/');
  assert.ok(d.sales && d.inventory && Array.isArray(d.recent_invoices));
  const range = { from: '2000-01-01', to: '2100-01-01' };
  for (const group of ['day', 'party', 'item']) {
    const r = await call('reports/sales', { query: { ...range, group } });
    assert.ok(Array.isArray(r.rows));
  }
  assert.ok(Array.isArray((await call('reports/receivables')).rows));
  assert.ok(Array.isArray((await call('reports/stock')).items));
  assert.ok((await call('reports/tax-summary', { query: range })).totals);
  assert.ok((await call('reports/parties')).top_dues);
  } finally { await s.close(); }
});
