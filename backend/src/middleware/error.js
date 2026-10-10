const { AppError } = require('../utils/errors');

// eslint-disable-next-line no-unused-vars
module.exports = (err, _req, res, _next) => {
  if (err instanceof AppError) {
    return res.status(err.status).json({ error: err.message, details: err.details });
  }
  if (err.code === '23505') return res.status(409).json({ error: 'Duplicate value', details: err.detail });
  if (err.code === '23503') return res.status(409).json({ error: 'This record is in use and cannot be changed that way', details: err.detail });
  if (err.code === '23514') return res.status(400).json({ error: 'Value violates a rule', details: err.constraint });
  if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'Invalid JSON body' });
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
};
