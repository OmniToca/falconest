-- Zápočet hotovosti na fakturu – kolik EUR bylo skutečně uhrazeno ze zálohy majitele.
-- PROČ: payment_status (partially_paid / cash_offset) nestačí pro zobrazení doplatku v UI.

ALTER TABLE public.billing_snapshots
  ADD COLUMN IF NOT EXISTS offset_amount numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS offset_request_id uuid REFERENCES public.owner_cash_disposition_requests(id),
  ADD COLUMN IF NOT EXISTS offset_applied_at timestamptz;

ALTER TABLE public.billing_snapshots
  DROP CONSTRAINT IF EXISTS billing_snapshots_offset_amount_nonneg;

ALTER TABLE public.billing_snapshots
  ADD CONSTRAINT billing_snapshots_offset_amount_nonneg
  CHECK (offset_amount >= 0);

COMMENT ON COLUMN public.billing_snapshots.offset_amount IS
  'Částka uhrazená zápočtem z hotovostní zálohy majitele (EUR nebo měna snapshotu).';

COMMENT ON COLUMN public.billing_snapshots.offset_request_id IS
  'Vazba na owner_cash_disposition_requests (typ invoice_credit), ze které byl zápočet čerpán.';

COMMENT ON COLUMN public.billing_snapshots.offset_applied_at IS
  'UTC čas posledního zápisu zápočtu (nullable – doplní aplikace při applyOffsetToSnapshot).';
