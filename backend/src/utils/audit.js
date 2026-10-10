async function audit(client, { businessId, userId, entity, entityId, action, details }) {
  await client.query(
    `INSERT INTO audit_logs (business_id, user_id, entity, entity_id, action, details) VALUES ($1,$2,$3,$4,$5,$6)`,
    [businessId, userId, entity, entityId ?? null, action, details ? JSON.stringify(details) : null]
  );
}
module.exports = { audit };
