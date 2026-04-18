-- =============================================================================
-- FalcoNest – sledování investic u bytů (investment tracking)
-- =============================================================================
-- PROČ: Agentura může u bytu zapnout příznak [investment_tracking_enabled] a držet
-- 1:1 metriky v [apartment_investment_metrics] (nákup, rekonstrukce, odhad trhu).
-- RLS: staff admin/manager spravuje celý tenant; majitel (property_owner) čte a mění
-- jen řádky u svých bytů přes [apartment_owners].
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Příznak na apartmánu
-- -----------------------------------------------------------------------------
ALTER TABLE public.apartments
  ADD COLUMN IF NOT EXISTS investment_tracking_enabled boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.apartments.investment_tracking_enabled IS
  'true = agentura/majitel sleduje investiční metriky (tabulka apartment_investment_metrics).';

-- -----------------------------------------------------------------------------
-- 2) Metriky 1:1 k bytu
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.apartment_investment_metrics (
  apartment_id uuid NOT NULL PRIMARY KEY
    REFERENCES public.apartments (id) ON DELETE CASCADE,
  purchase_price numeric NOT NULL DEFAULT 0,
  initial_renovation_cost numeric NOT NULL DEFAULT 0,
  estimated_market_price numeric NOT NULL DEFAULT 0,
  market_price_updated_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

COMMENT ON TABLE public.apartment_investment_metrics IS
  'Investiční čísla u bytu (1 řádek na apartment_id); RLS dle vlastnictví v apartment_owners.';

COMMENT ON COLUMN public.apartment_investment_metrics.purchase_price IS 'Pořizovací / nákupní cena (měna dle procesu agentury).';
COMMENT ON COLUMN public.apartment_investment_metrics.initial_renovation_cost IS 'Jednorázové počáteční náklady na rekonstrukci.';
COMMENT ON COLUMN public.apartment_investment_metrics.estimated_market_price IS 'Aktuální odhad tržní ceny.';
COMMENT ON COLUMN public.apartment_investment_metrics.market_price_updated_at IS 'Kdy byl naposledy aktualizován odhad trhu.';
COMMENT ON COLUMN public.apartment_investment_metrics.updated_at IS 'Poslední změna řádku (UTC); trigger při UPDATE.';

DROP TRIGGER IF EXISTS apartment_investment_metrics_updated_at_trigger ON public.apartment_investment_metrics;
CREATE TRIGGER apartment_investment_metrics_updated_at_trigger
  BEFORE UPDATE ON public.apartment_investment_metrics
  FOR EACH ROW
  EXECUTE FUNCTION public.set_dynamic_checklist_updated_at();

ALTER TABLE public.apartment_investment_metrics ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 3) RLS – admin / manager tenanta: plný přístup k řádkům bytů svého tenanta
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "apartment_investment_metrics_admin_manager_all" ON public.apartment_investment_metrics;

CREATE POLICY "apartment_investment_metrics_admin_manager_all"
  ON public.apartment_investment_metrics
  FOR ALL
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      public.is_tenant_admin_or_manager()
      AND EXISTS (
        SELECT 1
        FROM public.apartments a
        WHERE a.id = apartment_investment_metrics.apartment_id
          AND a.tenant_id = public.my_tenant_id()
          AND a.deleted_at IS NULL
      )
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      public.is_tenant_admin_or_manager()
      AND EXISTS (
        SELECT 1
        FROM public.apartments a
        WHERE a.id = apartment_investment_metrics.apartment_id
          AND a.tenant_id = public.my_tenant_id()
          AND a.deleted_at IS NULL
      )
    )
  );

COMMENT ON POLICY "apartment_investment_metrics_admin_manager_all" ON public.apartment_investment_metrics IS
  'INSERT/SELECT/UPDATE/DELETE: super_admin nebo admin/manager s bytem v rámci my_tenant_id().';

-- -----------------------------------------------------------------------------
-- 4) RLS – majitel: SELECT + UPDATE jen u svých bytů (bez INSERT/DELETE)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "apartment_investment_metrics_property_owner_select" ON public.apartment_investment_metrics;

CREATE POLICY "apartment_investment_metrics_property_owner_select"
  ON public.apartment_investment_metrics
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM public.apartment_owners ao
      WHERE ao.apartment_id = apartment_investment_metrics.apartment_id
        AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
        AND ao.deleted_at IS NULL
    )
  );

COMMENT ON POLICY "apartment_investment_metrics_property_owner_select" ON public.apartment_investment_metrics IS
  'SELECT: property_owner jen pro apartment_id z jeho apartment_owners.';

DROP POLICY IF EXISTS "apartment_investment_metrics_property_owner_update" ON public.apartment_investment_metrics;

CREATE POLICY "apartment_investment_metrics_property_owner_update"
  ON public.apartment_investment_metrics
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM public.apartment_owners ao
      WHERE ao.apartment_id = apartment_investment_metrics.apartment_id
        AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
        AND ao.deleted_at IS NULL
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM public.apartment_owners ao
      WHERE ao.apartment_id = apartment_investment_metrics.apartment_id
        AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
        AND ao.deleted_at IS NULL
    )
  );

COMMENT ON POLICY "apartment_investment_metrics_property_owner_update" ON public.apartment_investment_metrics IS
  'UPDATE: property_owner jen vlastní byty; nemění apartment_id (PK).';

NOTIFY pgrst, 'reload schema';
