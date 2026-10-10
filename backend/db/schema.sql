-- AVIRAXO / Galla Pro billing backend - Phase 1 schema (PostgreSQL 13+)
-- Money is stored as integer paise (1 rupee = 100 paise). Quantities are NUMERIC(14,3).
-- Business-owned tables use BIGINT identity ids so the mobile app can keep numeric ids.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid  TEXT NOT NULL UNIQUE,         -- Firebase Auth uid (or 'dev:<x>' in DEV_AUTH mode)
  email         TEXT,
  name          TEXT,
  last_login_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS businesses (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id  UUID NOT NULL REFERENCES users(id),
  name           TEXT NOT NULL,
  business_type  TEXT,                         -- retailer / wholesaler / distributor / manufacturer / services
  industry       TEXT,
  gst_registered BOOLEAN NOT NULL DEFAULT FALSE,
  gstin          TEXT,
  address        TEXT,
  state          TEXT,                         -- state name as the app shows it
  state_code     CHAR(2),                      -- GST state code derived from state / gstin
  pincode        TEXT,
  currency       TEXT NOT NULL DEFAULT 'INR',
  settings       JSONB NOT NULL DEFAULT '{}'::jsonb,  -- onboarding answers + app preferences (allowNegativeStock ...)
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS businesses_one_per_owner ON businesses (owner_user_id);

-- Membership. Phase 1 only uses role='owner'; Phase 2 (Staff, Roles & Permissions) builds on this.
CREATE TABLE IF NOT EXISTS business_users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL DEFAULT 'owner',
  status      TEXT NOT NULL DEFAULT 'active',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (business_id, user_id)
);

CREATE TABLE IF NOT EXISTS items (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id     UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  sku             TEXT NOT NULL DEFAULT '',
  category        TEXT NOT NULL DEFAULT '',
  unit            TEXT NOT NULL DEFAULT 'pcs',
  hsn             TEXT NOT NULL DEFAULT '',
  barcode         TEXT NOT NULL DEFAULT '',
  purchase_price  BIGINT NOT NULL DEFAULT 0 CHECK (purchase_price >= 0),
  selling_price   BIGINT NOT NULL DEFAULT 0 CHECK (selling_price >= 0),
  price_inclusive BOOLEAN NOT NULL DEFAULT FALSE,
  gst_rate        NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (gst_rate >= 0 AND gst_rate <= 100),
  gst_enabled     BOOLEAN NOT NULL DEFAULT FALSE,
  stock_enabled   BOOLEAN NOT NULL DEFAULT TRUE,
  low_stock_level INT NOT NULL DEFAULT 0 CHECK (low_stock_level >= 0),
  location        TEXT NOT NULL DEFAULT '',
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS items_biz ON items (business_id, is_active);

-- Immutable stock ledger. Current stock = SUM(qty_in - qty_out).
CREATE TABLE IF NOT EXISTS stock_movements (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  item_id     BIGINT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  qty_in      NUMERIC(14,3) NOT NULL DEFAULT 0 CHECK (qty_in >= 0),
  qty_out     NUMERIC(14,3) NOT NULL DEFAULT 0 CHECK (qty_out >= 0),
  reason      TEXT NOT NULL,          -- opening | purchase | sale | sale_cancel | adjustment
  ref_type    TEXT,                   -- invoice | item
  ref_id      BIGINT,
  note        TEXT,
  created_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS stock_mov_item ON stock_movements (business_id, item_id);

CREATE TABLE IF NOT EXISTS parties (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id      UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  phone            TEXT NOT NULL DEFAULT '',
  email            TEXT NOT NULL DEFAULT '',
  type             TEXT NOT NULL DEFAULT 'customer' CHECK (type IN ('customer','supplier','both')),
  gst_registered   BOOLEAN NOT NULL DEFAULT FALSE,
  gstin            TEXT NOT NULL DEFAULT '',
  state            TEXT NOT NULL DEFAULT '',
  billing_address  TEXT NOT NULL DEFAULT '',
  shipping_address TEXT NOT NULL DEFAULT '',
  opening_balance  BIGINT NOT NULL DEFAULT 0,   -- signed paise: positive = party owes us, negative = we owe party
  credit_limit     BIGINT NOT NULL DEFAULT 0 CHECK (credit_limit >= 0),  -- 0 = no limit
  payment_term     TEXT NOT NULL DEFAULT 'Immediate',
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS parties_biz ON parties (business_id, is_active);

-- Gap-free running numbers per business and series (INV, EST, PRO, DC), row-locked while a document is saved.
CREATE TABLE IF NOT EXISTS document_sequences (
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  series      TEXT NOT NULL,
  last_number INT NOT NULL DEFAULT 0,
  PRIMARY KEY (business_id, series)
);

CREATE TABLE IF NOT EXISTS invoices (
  id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id           UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  doc_type              TEXT NOT NULL CHECK (doc_type IN ('gstInvoice','retailInvoice','estimate','proforma','deliveryChallan')),
  affects_books         BOOLEAN NOT NULL,    -- true for gstInvoice / retailInvoice: moves stock, creates receivables
  invoice_no            TEXT NOT NULL,
  invoice_date          DATE NOT NULL,
  due_date              DATE,
  party_id              BIGINT REFERENCES parties(id),   -- NULL = cash / walk-in customer
  cash_customer         BOOLEAN NOT NULL DEFAULT FALSE,
  party_name            TEXT NOT NULL DEFAULT '',
  party_phone           TEXT NOT NULL DEFAULT '',
  party_gst_registered  BOOLEAN NOT NULL DEFAULT FALSE,
  business_name         TEXT NOT NULL DEFAULT '',
  business_address      TEXT NOT NULL DEFAULT '',
  business_gstin        TEXT NOT NULL DEFAULT '',
  business_state        TEXT NOT NULL DEFAULT '',
  currency              TEXT NOT NULL DEFAULT 'INR',
  gst_enabled           BOOLEAN NOT NULL DEFAULT FALSE,
  place_of_supply       CHAR(2),
  is_interstate         BOOLEAN NOT NULL DEFAULT FALSE,
  payment_method        TEXT NOT NULL DEFAULT 'Cash',
  notes                 TEXT NOT NULL DEFAULT '',
  terms                 TEXT NOT NULL DEFAULT '',
  subtotal              BIGINT NOT NULL,     -- sum(qty * rate) before discount
  discount_total        BIGINT NOT NULL DEFAULT 0,
  taxable_value         BIGINT NOT NULL,
  cgst                  BIGINT NOT NULL DEFAULT 0,
  sgst                  BIGINT NOT NULL DEFAULT 0,
  igst                  BIGINT NOT NULL DEFAULT 0,
  tax_total             BIGINT NOT NULL DEFAULT 0,
  grand_total           BIGINT NOT NULL,
  amount_paid           BIGINT NOT NULL DEFAULT 0,
  status                TEXT NOT NULL CHECK (status IN ('open','unpaid','partial','paid','cancelled')),
  cancelled_at          TIMESTAMPTZ,
  cancel_reason         TEXT,
  created_by            UUID REFERENCES users(id),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (amount_paid >= 0 AND amount_paid <= grand_total)
);
CREATE UNIQUE INDEX IF NOT EXISTS invoices_no_uq ON invoices (business_id, invoice_no);
CREATE INDEX IF NOT EXISTS invoices_biz_date ON invoices (business_id, invoice_date);
CREATE INDEX IF NOT EXISTS invoices_biz_party ON invoices (business_id, party_id);

CREATE TABLE IF NOT EXISTS invoice_lines (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  invoice_id          BIGINT NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  item_id             BIGINT REFERENCES items(id),
  name                TEXT NOT NULL,
  unit                TEXT NOT NULL DEFAULT 'pcs',
  hsn                 TEXT NOT NULL DEFAULT '',
  gst_slab            NUMERIC(5,2) NOT NULL DEFAULT 0,
  qty                 NUMERIC(14,3) NOT NULL CHECK (qty > 0),
  rate                BIGINT NOT NULL CHECK (rate >= 0),
  discount_is_percent BOOLEAN NOT NULL DEFAULT TRUE,
  discount_value      NUMERIC(14,3) NOT NULL DEFAULT 0,   -- percent, or paise when not percent
  line_base           BIGINT NOT NULL,
  discount_amount     BIGINT NOT NULL DEFAULT 0,
  taxable_value       BIGINT NOT NULL,
  tax_amount          BIGINT NOT NULL DEFAULT 0,
  cgst                BIGINT NOT NULL DEFAULT 0,
  sgst                BIGINT NOT NULL DEFAULT 0,
  igst                BIGINT NOT NULL DEFAULT 0,
  line_total          BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS invoice_lines_inv ON invoice_lines (invoice_id);

CREATE TABLE IF NOT EXISTS payments (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id  UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  direction    TEXT NOT NULL DEFAULT 'in' CHECK (direction IN ('in','out')),  -- 'out' is used from Phase 2 (suppliers)
  party_id     BIGINT REFERENCES parties(id),      -- NULL = walk-in cash sale
  payment_date DATE NOT NULL,
  amount       BIGINT NOT NULL CHECK (amount > 0),
  mode         TEXT NOT NULL CHECK (mode IN ('cash','upi','card','bank','cheque','other')),
  reference_no TEXT NOT NULL DEFAULT '',
  notes        TEXT NOT NULL DEFAULT '',
  created_by   UUID REFERENCES users(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS payments_biz_party ON payments (business_id, party_id);

CREATE TABLE IF NOT EXISTS payment_allocations (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  payment_id BIGINT NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  invoice_id BIGINT NOT NULL REFERENCES invoices(id),
  amount     BIGINT NOT NULL CHECK (amount > 0)
);
CREATE INDEX IF NOT EXISTS pay_alloc_inv ON payment_allocations (invoice_id);

CREATE TABLE IF NOT EXISTS audit_logs (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES users(id),
  entity      TEXT NOT NULL,
  entity_id   BIGINT,
  action      TEXT NOT NULL,
  details     JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS audit_biz ON audit_logs (business_id, created_at DESC);
