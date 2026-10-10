// Party balance is DERIVED from the ledger (never stored) so it cannot drift:
//   balance = opening_balance + sum(non-cancelled invoice totals) - sum(payments received)
// Positive = the party owes us. Negative = we hold an advance (or owe them, for suppliers).
const BALANCE_SQL = `
  p.opening_balance
  + COALESCE((SELECT SUM(i.grand_total) FROM invoices i WHERE i.party_id = p.id AND i.affects_books AND i.status <> 'cancelled'), 0)
  - COALESCE((SELECT SUM(py.amount) FROM payments py WHERE py.party_id = p.id AND py.direction = 'in'), 0)`;

const LAST_TXN_SQL = `
  GREATEST(p.created_at,
           COALESCE((SELECT MAX(i.created_at) FROM invoices i WHERE i.party_id = p.id), p.created_at),
           COALESCE((SELECT MAX(py.created_at) FROM payments py WHERE py.party_id = p.id), p.created_at))`;

const PARTY_SELECT = `SELECT p.*, (${BALANCE_SQL}) AS balance, ${LAST_TXN_SQL} AS last_txn_at FROM parties p`;

function partyJson(r) {
  return {
    id: r.id,
    name: r.name,
    phone: r.phone,
    email: r.email,
    type: r.type,
    gst_registered: r.gst_registered,
    gstin: r.gstin,
    state: r.state,
    billing_address: r.billing_address,
    shipping_address: r.shipping_address,
    opening_balance: Math.abs(r.opening_balance),
    to_receive: r.opening_balance >= 0,
    credit_limit: r.credit_limit,
    payment_term: r.payment_term,
    balance: r.balance,
    last_txn_at: r.last_txn_at,
    created_at: r.created_at,
    updated_at: r.updated_at,
  };
}

module.exports = { BALANCE_SQL, PARTY_SELECT, partyJson };
