-- =============================================================================
-- FalcoNest – Rozšíření dispozic hotovosti majitele a stavů úhrad u billing snapshotů
-- =============================================================================
-- PROČ Fáze 1: majitel může zadat IBAN u bankovního převodu; u zmražených
-- vyúčtování evidujeme stav úhrady, datum zaplacení/zápočtu a odkaz na PDF faktury.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. owner_cash_disposition_requests – IBAN pro bank_transfer
-- -----------------------------------------------------------------------------
ALTER TABLE public.owner_cash_disposition_requests
  ADD COLUMN IF NOT EXISTS iban text;

COMMENT ON COLUMN public.owner_cash_disposition_requests.iban IS
  'Volitelný IBAN / číslo účtu, pokud majitel zvolí bankovní převod (disposition_type = bank_transfer).';

-- -----------------------------------------------------------------------------
-- 2. billing_snapshots – stav úhrady a metadata faktury
-- -----------------------------------------------------------------------------
ALTER TABLE public.billing_snapshots
  ADD COLUMN IF NOT EXISTS payment_status text NOT NULL DEFAULT 'unpaid',
  ADD COLUMN IF NOT EXISTS paid_at timestamptz,
  ADD COLUMN IF NOT EXISTS invoice_pdf_url text;

COMMENT ON COLUMN public.billing_snapshots.payment_status IS
  'Stav úhrady zmraženého vyúčtování: unpaid | paid | cash_offset.';
COMMENT ON COLUMN public.billing_snapshots.paid_at IS
  'Okamžik uhrazení faktury nebo zápočtu (UTC).';
COMMENT ON COLUMN public.billing_snapshots.invoice_pdf_url IS
  'URL nahrané fyzické faktury (agentura); volitelné.';

-- CHECK: pouze povolené hodnoty (idempotentní opakování migrace)
ALTER TABLE public.billing_snapshots
  DROP CONSTRAINT IF EXISTS billing_snapshots_payment_status_check;

ALTER TABLE public.billing_snapshots
  ADD CONSTRAINT billing_snapshots_payment_status_check
  CHECK (payment_status IN ('unpaid', 'paid', 'cash_offset'));
