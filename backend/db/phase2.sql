-- AVIRAXO / Galla Pro - Phase 2+ schema additions (payment tracking, reminders, expenses, staff, sync).
-- Safe to re-run: every statement is idempotent. Applied after db/schema.sql by `npm run migrate`.

-- ---------- Payment tracking & automatic reminders ----------
ALTER TABLE parties ADD COLUMN IF NOT EXISTS reminders_paused BOOLEAN NOT NULL DEFAULT FALSE;

-- A reminder rule says WHEN to nudge about an unpaid invoice, relative to its due date.
--   before_due: offset_days days BEFORE the due date   on_due: on the due date   after_due: offset_days days AFTER it
-- repeat_every_days (after_due only) keeps nudging every N days until the invoice is paid.
CREATE TABLE IF NOT EXISTS reminder_rules (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id       UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  trigger_type      TEXT NOT NULL CHECK (trigger_type IN ('before_due','on_due','after_due')),
  offset_days       INT NOT NULL DEFAULT 0 CHECK (offset_days >= 0 AND offset_days <= 365),
  repeat_every_days INT CHECK (repeat_every_days IS NULL OR (repeat_every_days >= 1 AND repeat_every_days <= 90)),
  channel           TEXT NOT NULL DEFAULT 'whatsapp' CHECK (channel IN ('whatsapp','sms','email')),
  tone              TEXT NOT NULL DEFAULT 'friendly' CHECK (tone IN ('friendly','firm','final')),
  template          TEXT NOT NULL DEFAULT '',          -- empty = use the built-in text for the tone
  language          TEXT NOT NULL DEFAULT 'en' CHECK (language IN ('en','hi')),
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS reminder_rules_biz ON reminder_rules (business_id, is_active);

-- One row each time the owner sends (or skips) a reminder. Also what stops the same reminder showing up twice in a day.
CREATE TABLE IF NOT EXISTS reminder_log (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  party_id    BIGINT NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
  invoice_id  BIGINT REFERENCES invoices(id) ON DELETE SET NULL,
  rule_id     BIGINT REFERENCES reminder_rules(id) ON DELETE SET NULL,
  channel     TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','skipped')),
  message     TEXT NOT NULL DEFAULT '',
  amount_due  BIGINT NOT NULL DEFAULT 0,
  sent_on     DATE NOT NULL,
  created_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS reminder_log_party ON reminder_log (business_id, party_id, sent_on DESC);
CREATE INDEX IF NOT EXISTS reminder_log_rule ON reminder_log (business_id, invoice_id, rule_id, sent_on);

-- "I'll pay on Friday": while a promise is open and not yet due, after-due reminders for that party pause.
CREATE TABLE IF NOT EXISTS payment_promises (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id   UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  party_id      BIGINT NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
  invoice_id    BIGINT REFERENCES invoices(id) ON DELETE SET NULL,
  promised_date DATE NOT NULL,
  amount        BIGINT NOT NULL DEFAULT 0 CHECK (amount >= 0),     -- 0 = "whatever is due"
  note          TEXT NOT NULL DEFAULT '',
  status        TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','kept','broken','cancelled')),
  created_by    UUID REFERENCES users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS promises_party ON payment_promises (business_id, party_id, status);

-- ---------- Expenses & other income ----------
CREATE TABLE IF NOT EXISTS expenses (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id  UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  kind         TEXT NOT NULL DEFAULT 'expense' CHECK (kind IN ('expense','income')),   -- income = "other income"
  category     TEXT NOT NULL,
  amount       BIGINT NOT NULL CHECK (amount > 0),     -- paise, total including GST
  gst_amount   BIGINT NOT NULL DEFAULT 0 CHECK (gst_amount >= 0),
  mode         TEXT NOT NULL DEFAULT 'cash' CHECK (mode IN ('cash','upi','card','bank','cheque','other')),
  entry_date   DATE NOT NULL,
  party_id     BIGINT REFERENCES parties(id) ON DELETE SET NULL,
  note         TEXT NOT NULL DEFAULT '',
  receipt_url  TEXT NOT NULL DEFAULT '',
  recurring    TEXT CHECK (recurring IS NULL OR recurring IN ('weekly','monthly','yearly')),
  next_due     DATE,
  client_ref   TEXT,
  created_by   UUID REFERENCES users(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (gst_amount <= amount)
);
CREATE INDEX IF NOT EXISTS expenses_biz_date ON expenses (business_id, entry_date DESC);
CREATE UNIQUE INDEX IF NOT EXISTS expenses_client_ref ON expenses (business_id, client_ref) WHERE client_ref IS NOT NULL;

-- ---------- Offline billing: idempotent pushes ----------
-- The phone creates documents offline with a client-generated id; pushing the same one twice must not duplicate it.
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS client_ref TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS invoices_client_ref ON invoices (business_id, client_ref) WHERE client_ref IS NOT NULL;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS client_ref TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS payments_client_ref ON payments (business_id, client_ref) WHERE client_ref IS NOT NULL;

-- Estimate / proforma / challan -> invoice conversion link.
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS converted_to BIGINT REFERENCES invoices(id) ON DELETE SET NULL;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS converted_from BIGINT REFERENCES invoices(id) ON DELETE SET NULL;

-- ---------- Staff, roles and multiple firms ----------
CREATE TABLE IF NOT EXISTS staff_invites (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  role        TEXT NOT NULL CHECK (role IN ('manager','cashier','accountant','viewer')),
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','revoked')),
  invited_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS staff_invites_pending ON staff_invites (business_id, lower(email)) WHERE status = 'pending';

-- One owner may now run several firms (Vyapar's "multi-firm"). The app picks one with the X-Business-Id header.
DROP INDEX IF EXISTS businesses_one_per_owner;
