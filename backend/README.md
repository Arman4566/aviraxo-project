# Galla Pro Billing Backend (Phase 1) v2

Node.js 22 + Express + PostgreSQL. The server is the **source of truth**: it numbers invoices, does the GST maths,
moves stock and keeps customer balances. The Flutter app only sends what the user typed.

## Run
```bash
npm install
createdb galla_pro
cp .env.example .env          # set DATABASE_URL, FIREBASE_PROJECT_ID=galla-pro-b61ef
npm run migrate               # applies db/schema.sql (safe to re-run)
npm start                     # http://localhost:4000
```
Postman/curl without Firebase: set `DEV_AUTH=true` and send `Authorization: Bearer dev:<any-uid>:<email>`
(never enable in production). In production the app sends its Firebase ID token, verified against Google's public keys.

## Tests
```bash
npm test                                  # unit tests (GST maths, Firebase token checks, helpers)
createdb aviraxo_it && psql aviraxo_it -f db/schema.sql
TEST_DB=aviraxo_it npm test               # + real PostgreSQL scenarios (sales, payments, stock, isolation, reports SQL)
```

## API (all under /api, JSON, money in integer paise)
| | |
|--|--|
| GET /me | user + business (null for a new account → app shows onboarding) |
| PUT /business | create/update business (name, GST, address, state, `settings` JSON) |
| GET/POST /items, GET/PUT/DELETE /items/:id | catalogue; stock is derived from a ledger |
| POST /items/:id/purchase-entry, /adjust; GET /items/:id/movements | stock in / corrections |
| GET/POST /parties, GET/PUT/DELETE /parties/:id, GET /parties/:id/ledger | customers & suppliers, live balance, statement |
| GET /invoices/next-number?doc_type= | preview of next number |
| POST /invoices | create (gstInvoice, retailInvoice, estimate, proforma, deliveryChallan) |
| GET /invoices, GET /invoices/:id, POST /invoices/:id/cancel | list (filters), detail with lines+payments, cancel |
| POST /payments, GET /payments | money received (explicit allocation or oldest-first) |
| GET /dashboard | home screen numbers in one call |
| GET /reports/sales, /receivables, /stock, /tax-summary, /parties | reports |

Errors: `{ "error": "human readable message" }` with 400/401/404/409/428. `428` = signed in but no business yet.

## Rules enforced on the server
Per-business isolation · gap-free numbering per series · stock can't go negative (unless the business allows it) ·
credit limit check · walk-in customers can't buy on credit · amount paid can never exceed the invoice ·
GST only for GST-registered businesses; CGST+SGST within the state, IGST across states · cancelling restores stock.

## Phase 2-6 additions

Run `npm run migrate` once: it now applies `db/schema.sql` and then `db/phase2.sql` (safe to re-run).

| Area | Endpoints |
|---|---|
| Payment tracking | `GET /api/receivables/summary`, `/aging`, `/parties`; `PUT /api/receivables/parties/:id/reminders` (pause/resume) |
| Reminders | `GET/POST/PUT/DELETE /api/reminders/rules`, `GET /api/reminders/due`, `POST /api/reminders/compose`, `POST/GET /api/reminders/log` |
| Promise to pay | `POST/GET /api/promises`, `PUT /api/promises/:id` |
| Expenses | `/api/expenses` (CRUD, recurring), `/categories`, `/summary` |
| Inventory | `GET /api/inventory/low-stock`, `GET /api/inventory/barcode/:code` |
| Documents | `POST /api/invoices/:id/convert` (estimate / proforma / challan to invoice) |
| Reports | `/api/reports/profit-loss`, `/day-book`, `/cash-flow`, `/cash-bank`, `/gstr1`, `/gstr3b` |
| Team | `/api/staff` (+ `/invite`, `/invites/:id`, `/:id`, `/audit/log`); roles owner, manager, cashier, accountant, viewer |
| Multi-firm | `X-Business-Id` header; `POST /api/business/new`; `GET /api/me` lists all firms |
| Backup | `GET /api/backup/export`, `POST /api/backup/restore` (owner, into an empty firm) |
| Insights | `/api/insights/summary`, `/forecast`, `/risk/:partyId`, `/check-invoice`, `/gstin/:gstin` |

Offline sync: `POST /api/invoices`, `/api/payments` and `/api/expenses` accept `client_ref`; sending the same one twice returns the original instead of creating a duplicate.

Reminders: the server works out who to chase and writes the message plus `wa.me`, `sms:`, `mailto:` and UPI links; the owner taps send. Fully automatic sending needs a WhatsApp Business API or SMS gateway account.

Tests: `TEST_DB=<db> PGHOST=... PGUSER=... npm test` (82 tests; database tests need PostgreSQL).
