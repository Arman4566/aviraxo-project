// Security middleware and hardening checks. No database or Express needed.
const test = require('node:test');
const assert = require('node:assert/strict');
const { rateLimit, corsAllowList, apiHeaders } = require('../src/middleware/security');
const errorHandler = require('../src/middleware/error');
const { AppError } = require('../src/utils/errors');

const fakeRes = () => {
  const h = {};
  return { headers: h, statusCode: 200, ended: false, body: undefined,
    setHeader(k, v) { h[k] = v; }, end() { this.ended = true; },
    status(c) { this.statusCode = c; return this; }, json(b) { this.body = b; return this; } };
};

test('rate limiter allows up to max, then answers 429, then recovers after the window', () => {
  let t = 1000;
  const lim = rateLimit({ windowMs: 60_000, max: 3, now: () => t });
  const req = { ip: '1.2.3.4' };
  const run = () => { let err; lim(req, fakeRes(), (e) => { err = e; }); return err; };
  assert.equal(run(), undefined); assert.equal(run(), undefined); assert.equal(run(), undefined);
  const blocked = run();
  assert.ok(blocked instanceof AppError); assert.equal(blocked.status, 429);
  t += 60_001;
  assert.equal(run(), undefined);
});

test('rate limiter counts clients separately and sets Retry-After', () => {
  const lim = rateLimit({ windowMs: 60_000, max: 1 });
  const res = fakeRes(); let err;
  lim({ ip: 'a' }, fakeRes(), () => {});
  lim({ ip: 'a' }, res, (e) => { err = e; });
  assert.equal(err.status, 429); assert.ok(Number(res.headers['Retry-After']) > 0);
  let other; lim({ ip: 'b' }, fakeRes(), (e) => { other = e; });
  assert.equal(other, undefined);
});

test('rate limiter keyed by user does not mix users sharing one address', () => {
  const lim = rateLimit({ windowMs: 60_000, max: 1, key: (r) => r.user.id });
  let a, b;
  lim({ ip: 'x', user: { id: 1 } }, fakeRes(), () => {});
  lim({ ip: 'x', user: { id: 2 } }, fakeRes(), (e) => { b = e; });
  lim({ ip: 'x', user: { id: 1 } }, fakeRes(), (e) => { a = e; });
  assert.equal(b, undefined); assert.equal(a.status, 429);
});

test('CORS: unknown origins get no CORS headers, listed ones do, preflight from unknown is refused', () => {
  const cors = corsAllowList(['https://app.example.com']);
  let res = fakeRes(); let called = false;
  cors({ method: 'GET', headers: { origin: 'https://evil.example' } }, res, () => { called = true; });
  assert.ok(called); assert.equal(res.headers['Access-Control-Allow-Origin'], undefined);
  res = fakeRes();
  cors({ method: 'GET', headers: { origin: 'https://app.example.com' } }, res, () => {});
  assert.equal(res.headers['Access-Control-Allow-Origin'], 'https://app.example.com');
  res = fakeRes();
  cors({ method: 'OPTIONS', headers: { origin: 'https://evil.example' } }, res, () => assert.fail('must not continue'));
  assert.equal(res.statusCode, 403); assert.ok(res.ended);
  res = fakeRes();
  cors({ method: 'POST', headers: {} }, res, () => {});          // mobile app: no Origin header, unaffected
  assert.equal(res.headers['Access-Control-Allow-Origin'], undefined);
});

test('API responses are never cacheable and carry a request id', () => {
  const res = fakeRes(); const req = {};
  apiHeaders(req, res, () => {});
  assert.equal(res.headers['Cache-Control'], 'no-store');
  assert.match(res.headers['X-Request-Id'], /^[0-9a-f-]{36}$/); assert.equal(req.id, res.headers['X-Request-Id']);
});

test('error handler hides database details and stack in production', () => {
  const prev = process.env.NODE_ENV; process.env.NODE_ENV = 'production';
  try {
    let res = fakeRes();
    errorHandler({ code: '23505', detail: 'Key (email)=(secret@x.com) already exists.' }, {}, res, () => {});
    assert.equal(res.statusCode, 409); assert.equal(res.body.details, undefined);
    res = fakeRes();
    const orig = console.error; console.error = () => {};
    errorHandler(new Error('connect ECONNREFUSED 10.0.0.5:5432 password=hunter2'), { id: 'rid' }, res, () => {});
    console.error = orig;
    assert.equal(res.statusCode, 500); assert.equal(res.body.error, 'Internal server error');
    assert.ok(!JSON.stringify(res.body).includes('hunter2'));
    assert.equal(res.body.request_id, 'rid');
  } finally { process.env.NODE_ENV = prev; }
});

test('oversized request body gets 413, not 500', () => {
  const res = fakeRes(); const orig = console.error; console.error = () => {};
  errorHandler({ type: 'entity.too.large' }, {}, res, () => {}); console.error = orig;
  assert.equal(res.statusCode, 413);
});

test('xlsx reader refuses a zip bomb', () => {
  const zlib = require('node:zlib');
  const { writeXlsx, readXlsx } = require('../src/utils/xlsx');
  assert.ok(readXlsx(writeXlsx([{ name: 'A', rows: [['x', 1]] }])).length === 1);   // normal files still work
  // craft an entry whose inflated size is far above the cap
  const big = zlib.deflateRawSync(Buffer.alloc(60_000_000, 0x61));
  const name = Buffer.from('xl/sharedStrings.xml');
  const lh = Buffer.alloc(30); lh.writeUInt32LE(0x04034b50, 0); lh.writeUInt16LE(name.length, 26);
  const cd = Buffer.alloc(46); cd.writeUInt32LE(0x02014b50, 0); cd.writeUInt16LE(8, 10); cd.writeUInt32LE(big.length, 20);
  cd.writeUInt16LE(name.length, 28); cd.writeUInt32LE(0, 42);
  const eo = Buffer.alloc(22); eo.writeUInt32LE(0x06054b50, 0); eo.writeUInt16LE(1, 10);
  const body = Buffer.concat([lh, name, big]);
  eo.writeUInt32LE(body.length, 16);
  assert.throws(() => readXlsx(Buffer.concat([body, cd, name, eo])));
});
