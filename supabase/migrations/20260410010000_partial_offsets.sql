-- =============================================================================
-- FalcoNest – Částečné umoření žádostí + UPDATE billing_snapshots (admin/manager)
-- =============================================================================
-- PROČ: [used_amount] sleduje již vyčerpanou část žádosti; stav [partially_completed].
-- U faktur (snapshot) stav [partially_paid] + RLS UPDATE pro úpravu úhrad.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. owner_cash_disposition_requests – čerpání částky
-- -----------------------------------------------------------------------------
ALTER TABLE public.owner_cash_disposition_requests
  ADD COLUMN IF NOT EXISTS used_amount numeric NOT NULL DEFAULT 0;

ALTER TABLE public.owner_cash_disposition_requests
  DROP CONSTRAINT IF EXISTS owner_cash_disposition_requests_used_amount_check;

ALTER TABLE public.owner_cash_disposition_requests
  ADD CONSTRAINT owner_cash_disposition_requests_used_amount_check
  CHECK (used_amount >= 0);

COMMENT ON COLUMN public.owner_cash_disposition_requests.used_amount IS
  'Součet částek již uplatněných proti žádosti (např. umoření faktury); nesmí překročit amount.';

-- Nahrazení CHECK na status o hodnotu partially_completed (PostgreSQL pojmenování inline CHECK).
ALTER TABLE public.owner_cash_disposition_requests
  DROP CONSTRAINT IF EXISTS owner_cash_disposition_requests_status_check;

ALTER TABLE public.owner_cash_disposition_requests
  ADD CONSTRAINT owner_cash_disposition_requests_status_check
  CHECK (
    status IN (
      'pending',
      'approved',
      'rejected',
      'completed',
      'partially_completed'
    )
  );

-- -----------------------------------------------------------------------------
-- 2. billing_snapshots – rozšíření payment_status + UPDATE RLS
-- -----------------------------------------------------------------------------
ALTER TABLE public.billing_snapshots
  DROP CONSTRAINT IF EXISTS billing_snapshots_payment_status_check;

ALTER TABLE public.billing_snapshots
  ADD CONSTRAINT billing_snapshots_payment_status_check
  CHECK (
    payment_status IN ('unpaid', 'paid', 'cash_offset', 'partially_paid')
  );

COMMENT ON COLUMN public.billing_snapshots.payment_status IS
  'Stav úhrady: unpaid | paid | cash_offset | partially_paid.';

-- Admin / manager tenanta: UPDATE řádků fakturace (úhrady, PDF URL atd.).
DROP POLICY IF EXISTS "billing_snapshots_update_admin_manager" ON public.billing_snapshots;

CREATE POLICY "billing_snapshots_update_admin_manager"
  ON public.billing_snapshots
  FOR UPDATE
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      billing_snapshots.tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles AS p_upd
        WHERE p_upd.auth_id = auth.uid()
          AND p_upd.tenant_id = billing_snapshots.tenant_id
          AND p_upd.role IN ('admin', 'manager')
      )
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      billing_snapshots.tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.profiles AS p_wc
        WHERE p_wc.auth_id = auth.uid()
          AND p_wc.tenant_id = billing_snapshots.tenant_id
          AND p_wc.role IN ('admin', 'manager')
      )
    )
  );
