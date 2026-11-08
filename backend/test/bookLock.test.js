// Books lock middleware: blocks dated writes on or before the lock day, never blocks reads or later dates.
const test = require('node:test');
const assert = require('node:assert/strict');
const { bookLock } = require('../src/middleware/bookLock');
const { todayIST } = require('../src/utils/time');

const run = (mw, req) => new Promise((resolve) => mw({ body: {}, ...req }, {}, (err) => resolve(err || null)));
const biz = (lock) => ({ id: 1, settings: lock ? { booksLockedUntil: lock } : {} });

test('no lock set: everything passes', async () => {
  assert.equal(await run(bookLock('invoices'), { method: 'POST', path: '/', business: biz(null), body: { invoice_date: '2020-01-01' } }), null);
});

test('invoice create: locked day and earlier are rejected, later days pass, reads pass', async () => {
  const mw = bookLock('invoices');
  const b = biz('2026-03-31');
  const e1 = await run(mw, { method: 'POST', path: '/', business: b, body: { invoice_date: '2026-03-31' } });
  assert.equal(e1.status, 403);
  assert.match(e1.message, /locked up to 2026-03-31/);
  assert.equal((await run(mw, { method: 'POST', path: '/', business: b, body: { invoice_date: '2026-01-05' } })).status, 403);
  assert.equal(await run(mw, { method: 'POST', path: '/', business: b, body: { invoice_date: '2026-04-01' } }), null);
  assert.equal(await run(mw, { method: 'POST', path: '/', business: b, body: {} }), null);               // defaults to today
  assert.equal(await run(mw, { method: 'GET', path: '/', business: b }), null);
});

test('cancel and expense edits look up the stored date', async () => {
  const lookup = async (sql, params) => ({ rows: [{ d: params[0] === 7 ? '2026-02-10' : '2026-06-10' }] });
  const b = biz('2026-03-31');
  assert.equal((await run(bookLock('invoices', { lookup }), { method: 'POST', path: '/7/cancel', business: b })).status, 403);
  assert.equal(await run(bookLock('invoices', { lookup }), { method: 'POST', path: '/8/cancel', business: b }), null);
  assert.equal((await run(bookLock('expenses', { lookup }), { method: 'DELETE', path: '/7', business: b })).status, 403);
  assert.equal((await run(bookLock('expenses', { lookup }), { method: 'PUT', path: '/8', business: b, body: { entry_date: '2026-03-01' } })).status, 403);
  assert.equal(await run(bookLock('payments'), { method: 'POST', path: '/', business: biz(todayIST()), body: { payment_date: '2099-01-01' } }), null);
  assert.equal((await run(bookLock('payments'), { method: 'POST', path: '/', business: biz(todayIST()) })).status, 403); // today <= lock today
});

test('garbage lock values are ignored', async () => {
  assert.equal(await run(bookLock('invoices'), { method: 'POST', path: '/', business: { id: 1, settings: { booksLockedUntil: 'tomorrow' } }, body: { invoice_date: '2020-01-01' } }), null);
});
