-- =============================================================================
-- FalcoNest – Stripe Billing: rozšíření tenants, tenant_modules a tabulka invoices
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Rozšíření public.tenants
-- -----------------------------------------------------------------------------
ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS stripe_customer_id text;

ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS billing_email text;

-- -----------------------------------------------------------------------------
-- 2. Rozšíření public.tenant_modules
-- -----------------------------------------------------------------------------
ALTER TABLE public.tenant_modules
  ADD COLUMN IF NOT EXISTS stripe_subscription_id text;

ALTER TABLE public.tenant_modules
  ADD COLUMN IF NOT EXISTS stripe_price_id text;

ALTER TABLE public.tenant_modules
  ADD COLUMN IF NOT EXISTS cancel_at_period_end boolean NOT NULL DEFAULT false;

-- -----------------------------------------------------------------------------
-- 3. Nová tabulka public.invoices
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  stripe_invoice_id text,
  amount_due numeric NOT NULL,
  amount_paid numeric NOT NULL,
  currency text NOT NULL DEFAULT 'eur',
  status text NOT NULL,
  invoice_pdf_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  paid_at timestamptz
);

-- -----------------------------------------------------------------------------
-- 4. RLS pro public.invoices
-- -----------------------------------------------------------------------------
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- Super Admin má plný přístup
DROP POLICY IF EXISTS "invoices_super_admin_full" ON public.invoices;
CREATE POLICY "invoices_super_admin_full"
  ON public.invoices
  FOR ALL
  TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- Tenant vidí jen vlastní faktury (SELECT)
DROP POLICY IF EXISTS "invoices_select_own_tenant" ON public.invoices;
CREATE POLICY "invoices_select_own_tenant"
  ON public.invoices
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );
