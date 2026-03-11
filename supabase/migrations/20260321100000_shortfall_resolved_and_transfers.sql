-- =============================================================================
-- FalcoNest – Vyřešení nedoplatků v hotovosti (Podklady pro fakturaci)
-- =============================================================================
-- 1) Sloupce v employee_cash_transactions: is_shortfall_resolved, typ a poznámka
--    vyřešení. 2) Tabulka billing_shortfall_transfers pro položku „Přenést na
--    majitele“ (nedoplatek jako extra řádek na faktuře).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. employee_cash_transactions – sledování vyřešení nedoplatku
-- -----------------------------------------------------------------------------
ALTER TABLE public.employee_cash_transactions
  ADD COLUMN IF NOT EXISTS is_shortfall_resolved boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS shortfall_resolution_type text,
  ADD COLUMN IF NOT EXISTS shortfall_resolution_note text;

COMMENT ON COLUMN public.employee_cash_transactions.is_shortfall_resolved IS
  'TRUE = dispečer nedoplatek vyřešil (přenos na majitele / odpis / jinak).';
COMMENT ON COLUMN public.employee_cash_transactions.shortfall_resolution_type IS
  'transfer_to_owner | write_off | other';
COMMENT ON COLUMN public.employee_cash_transactions.shortfall_resolution_note IS
  'Poznámka k vyřešení (např. u „Jinak“).';

-- -----------------------------------------------------------------------------
-- 2. billing_shortfall_transfers – nedoplatek převedený na fakturu majitele
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.billing_shortfall_transfers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  amount numeric NOT NULL CHECK (amount > 0),
  description text,
  task_id uuid REFERENCES public.tasks(id) ON DELETE SET NULL,
  cash_transaction_id uuid NOT NULL REFERENCES public.employee_cash_transactions(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.billing_shortfall_transfers IS
  'Nedoplatky z hotovosti převedené na fakturu majitele – zobrazí se v Podkladech a v PDF.';

CREATE INDEX IF NOT EXISTS idx_billing_shortfall_transfers_tenant
  ON public.billing_shortfall_transfers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_billing_shortfall_transfers_client_created
  ON public.billing_shortfall_transfers(client_id, created_at);

ALTER TABLE public.billing_shortfall_transfers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "billing_shortfall_transfers_select"
  ON public.billing_shortfall_transfers FOR SELECT
  USING (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) != 'property_owner'
      AND tenant_id = public.my_tenant_id()
    )
  );

CREATE POLICY "billing_shortfall_transfers_insert"
  ON public.billing_shortfall_transfers FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) IN ('admin', 'manager')
      AND tenant_id = public.my_tenant_id()
    )
  );

CREATE POLICY "billing_shortfall_transfers_update"
  ON public.billing_shortfall_transfers FOR UPDATE
  USING (
    public.is_super_admin()
    OR (tenant_id = public.my_tenant_id())
  );
