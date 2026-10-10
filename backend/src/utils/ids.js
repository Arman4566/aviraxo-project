const { badRequest } = require('./errors');

/** Parses a positive integer id from a path/body value, or throws a 400. */
function parseId(value, label = 'id') {
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n <= 0) throw badRequest(`Invalid ${label}`);
  return n;
}
module.exports = { parseId };
