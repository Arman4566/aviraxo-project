const { AppError } = require('../utils/errors');

// Database "detail" text can quote real values (emails, numbers), so it is only sent outside production.
const dbDetail = (err) => (process.env.NODE_ENV === 'production' ? undefined : err.detail);

// eslint-disable-next-line no-unused-vars
module.exports = (err, req, res, _next) => {
  if (err instanceof AppError) {
    return res.status(err.status).json({ error: err.message, details: err.details });
  }
  if (err.code === '23505') return res.status(409).json({ error: 'Duplicate value', details: dbDetail(err) });
  if (err.code === '23503') return res.status(409).json({ error: 'This record is in use and cannot be changed that way', details: dbDetail(err) });
  if (err.code === '23514') return res.status(400).json({ error: 'Value violates a rule', details: process.env.NODE_ENV === 'production' ? undefined : err.constraint });
  if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'Invalid JSON body' });
  if (err.type === 'entity.too.large') return res.status(413).json({ error: 'Request is too large' });
  console.error(`[${(req && req.id) || '-'}]`, err);
  res.status(500).json({ error: 'Internal server error', request_id: (req && req.id) || undefined });
};
