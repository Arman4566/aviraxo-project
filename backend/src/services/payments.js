const { badRequest } = require('../utils/errors');

/**
 * Records a payment received and allocates it to invoices. Must run inside a transaction (pass the client).
 * - explicit allocations: [{invoice_id, amount}] are validated against each invoice's outstanding amount
 * - no allocations + party: settled oldest-first (FIFO) against the party's open invoices
 * - leftover stays unallocated (an advance) and still reduces the party's balance
 * partyId may be null for a walk-in cash sale (then allocations are required).
 */
async function recordPayment(c, { businessId, userId, partyId, amount, mode, paymentDate, referenceNo, notes, allocations, clientRef }) {
  if (!Number.isInteger(amount) || amount <= 0) throw badRequest('amount must be a positive whole number of paise');

  // Offline billing: a repeated client_ref returns the payment already saved instead of recording it twice.
  if (clientRef) {
    const { rows: dup } = await c.query('SELECT * FROM payments WHERE business_id = $1 AND client_ref = $2', [businessId, clientRef]);
    if (dup[0]) {
      const { rows: al } = await c.query('SELECT invoice_id, amount FROM payment_allocations WHERE payment_id = $1', [dup[0].id]);
      const allocated = al.reduce((s, a) => s + a.amount, 0);
      return { payment: dup[0], allocations: al, allocated, unallocated: dup[0].amount - allocated, duplicate: true };
    }
  }

  const { rows } = await c.query(
    `INSERT INTO payments (business_id, direction, party_id, payment_date, amount, mode, reference_no, notes, created_by, client_ref)
     VALUES ($1,'in',$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
    [businessId, partyId || null, paymentDate, amount, mode, referenceNo || '', notes || '', userId, clientRef || null]
  );
  const payment = rows[0];

  let plan = [];
  if (allocations && allocations.length) {
    const ids = allocations.map((a) => a.invoice_id);
    if (new Set(ids).size !== ids.length) throw badRequest('Duplicate invoice in allocations');
    const { rows: invs } = await c.query(
      `SELECT id, grand_total, amount_paid, status, party_id, affects_books FROM invoices
        WHERE business_id = $1 AND id = ANY($2::bigint[]) FOR UPDATE`,
      [businessId, ids]
    );
    if (invs.length !== ids.length) throw badRequest('One or more invoices were not found');
    const byId = new Map(invs.map((i) => [i.id, i]));
    for (const a of allocations) {
      const inv = byId.get(a.invoice_id);
      if (!inv.affects_books) throw badRequest('Payments can only be applied to invoices, not estimates or challans');
      if (inv.status === 'cancelled') throw badRequest('Cannot allocate to a cancelled invoice');
      if (partyId && inv.party_id !== partyId) throw badRequest('Invoice does not belong to this party');
      if (a.amount > inv.grand_total - inv.amount_paid) throw badRequest('Allocation exceeds the invoice outstanding amount');
    }
    if (allocations.reduce((s, a) => s + a.amount, 0) > amount) throw badRequest('Allocated total exceeds the payment amount');
    plan = allocations.map((a) => ({ invoice_id: a.invoice_id, amount: a.amount }));
  } else if (partyId) {
    const { rows: open } = await c.query(
      `SELECT id, grand_total, amount_paid FROM invoices
        WHERE business_id = $1 AND party_id = $2 AND affects_books AND status IN ('unpaid','partial')
        ORDER BY invoice_date, id FOR UPDATE`,
      [businessId, partyId]
    );
    let left = amount;
    for (const inv of open) {
      if (left <= 0) break;
      const take = Math.min(inv.grand_total - inv.amount_paid, left);
      plan.push({ invoice_id: inv.id, amount: take });
      left -= take;
    }
  }

  for (const p of plan) {
    await c.query(`INSERT INTO payment_allocations (payment_id, invoice_id, amount) VALUES ($1,$2,$3)`, [payment.id, p.invoice_id, p.amount]);
    await c.query(
      `UPDATE invoices SET amount_paid = amount_paid + $2,
              status = CASE WHEN amount_paid + $2 >= grand_total THEN 'paid' ELSE 'partial' END,
              updated_at = now()
        WHERE id = $1`,
      [p.invoice_id, p.amount]
    );
  }
  const allocated = plan.reduce((s, p) => s + p.amount, 0);
  return { payment, allocations: plan, allocated, unallocated: amount - allocated };
}

module.exports = { recordPayment };
