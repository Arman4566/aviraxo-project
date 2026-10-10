// Express 4 does not catch rejected promises; wrap async handlers so errors reach the error middleware.
module.exports = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
