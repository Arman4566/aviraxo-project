// Dependency-free security middleware: rate limiting, CORS allow-list, no-store caching, request-id.
// Plain (req, res, next) functions, so they are unit-testable without Express.
const crypto = require('node:crypto');
const { AppError } = require('../utils/errors');

/**
 * Fixed-window limiter held in memory (resets on restart; one Render instance is enough for this app).
 * key(req) decides who is counted: the client IP by default, or the signed-in user.
 */
function rateLimit({ windowMs, max, key = (req) => req.ip || (req.socket && req.socket.remoteAddress) || 'unknown', message = 'Too many requests. Please slow down and try again shortly.', now = Date.now }) {
  const hits = new Map();
  let lastSweep = now();
  return function limiter(req, res, next) {
    const t = now();
    if (t - lastSweep > windowMs) {                       // drop expired windows so the map cannot grow forever
      for (const [k, v] of hits) if (v.reset <= t) hits.delete(k);
      lastSweep = t;
    }
    const k = String(key(req));
    let h = hits.get(k);
    if (!h || h.reset <= t) { h = { n: 0, reset: t + windowMs }; hits.set(k, h); }
    h.n += 1;
    const left = Math.max(0, max - h.n);
    if (res.setHeader) {
      res.setHeader('RateLimit-Limit', String(max));
      res.setHeader('RateLimit-Remaining', String(left));
      res.setHeader('RateLimit-Reset', String(Math.ceil((h.reset - t) / 1000)));
    }
    if (h.n > max) {
      if (res.setHeader) res.setHeader('Retry-After', String(Math.ceil((h.reset - t) / 1000)));
      return next(new AppError(429, message));
    }
    next();
  };
}

/**
 * CORS: the mobile app does not use CORS at all. Browsers are only allowed from origins listed in CORS_ORIGINS
 * (comma separated). With no list, no browser origin is allowed.
 */
function corsAllowList(origins) {
  const allowed = new Set(origins);
  return function cors(req, res, next) {
    const origin = req.headers && req.headers.origin;
    if (origin && allowed.has(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
      res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Business-Id');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
      res.setHeader('Access-Control-Max-Age', '600');
    }
    if (req.method === 'OPTIONS') { res.statusCode = origin && allowed.has(origin) ? 204 : 403; return res.end(); }
    next();
  };
}

/** API answers hold private business data: never let a browser or proxy cache them. Adds a request id for log tracing. */
function apiHeaders(req, res, next) {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Pragma', 'no-cache');
  const id = crypto.randomUUID();
  req.id = id;
  res.setHeader('X-Request-Id', id);
  next();
}

module.exports = { rateLimit, corsAllowList, apiHeaders };
