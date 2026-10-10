const { badRequest } = require('../utils/errors');

/** validate(schema, 'body'|'query') - parses with zod and replaces req[part] with the parsed value. */
module.exports = (schema, part = 'body') => (req, _res, next) => {
  const r = schema.safeParse(req[part]);
  if (!r.success) {
    const issues = r.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message }));
    const first = issues[0];
    return next(badRequest(first ? `${first.path || 'request'}: ${first.message}` : 'Validation failed', issues));
  }
  req[part] = r.data;
  next();
};
