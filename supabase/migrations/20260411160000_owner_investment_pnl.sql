-- =============================================================================
-- FalcoNest – měsíční P&L záznamy majitele (vlastní příjmy / výdaje)
-- =============================================================================
-- PROČ: Majitel zadává souhrn „příjmy od hostů“ a „externí výdaje“ za měsíc;
-- unikátní trojice (apartment_id, entry_month, entry_type) = max. jeden řádek
-- income a jeden expense na měsíc. Admin může číst a mazat (support), nesmí měnit
-- hodnoty majitele (žádný INSERT/UPDATE pro staff).
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.apartment_investment_pnl_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  apartment_id uuid NOT NULL REFERENCES public.apartments (id) ON DELETE CASCADE,
  entry_month date NOT NULL,
  entry_type text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  description text,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  CONSTRAINT apartment_investment_pnl_entries_entry_type_check
    CHECK (entry_type IN ('income', 'expense')),
  CONSTRAINT apartment_investment_pnl_entries_entry_month_first_day_check
    CHECK (EXTRACT(DAY FROM entry_month) = 1),
  CONSTRAINT apartment_investment_pnl_entries_apartment_month_type_uniq
    UNIQUE (apartment_id, entry_month, entry_type)
);

COMMENT ON TABLE public.apartment_investment_pnl_entries IS
  'Měsíční souhrn P&L od majitele: income = příjmy od hostů, expense = vlastní externí náklady; agenturní položky budou později z billing/tasks.';

COMMENT ON COLUMN public.apartment_investment_pnl_entries.entry_month IS
  'První den kalendářního měsíce (UTC datum), např. 2026-04-01.';

COMMENT ON COLUMN public.apartment_investment_pnl_entries.entry_type IS
  'income | expense – jeden řádek typu na měsíc a byt.';

CREATE INDEX IF NOT EXISTS idx_apartment_investment_pnl_apartment_month
  ON public.apartment_investment_pnl_entries (apartment_id, entry_month DESC);

DROP TRIGGER IF EXISTS apartment_investment_pnl_entries_updated_at_trigger
  ON public.apartment_investment_pnl_entries;
CREATE TRIGGER apartment_investment_pnl_entries_updated_at_trigger
  BEFORE UPDATE ON public.apartment_investment_pnl_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.set_dynamic_checklist_updated_at();

ALTER TABLE public.apartment_investment_pnl_entries ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- Majitel: plný přístup k řádkům svých bytů
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "apartment_investment_pnl_entries_property_owner_all" ON public.apartment_investment_pnl_entries;

CREATE POLICY "apartment_investment_pnl_entries_property_owner_all"
  ON public.apartment_investment_pnl_entries
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM public.apartment_owners ao
      WHERE ao.apartment_id = apartment_investment_pnl_entries.apartment_id
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
      WHERE ao.apartment_id = apartment_investment_pnl_entries.apartment_id
        AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
        AND ao.deleted_at IS NULL
    )
  );

COMMENT ON POLICY "apartment_investment_pnl_entries_property_owner_all" ON public.apartment_investment_pnl_entries IS
  'Majitel (property_owner): SELECT/INSERT/UPDATE/DELETE jen u vlastních bytů.';

-- -----------------------------------------------------------------------------
-- Admin / manager: SELECT (přehled), DELETE (support) – bez INSERT/UPDATE
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "apartment_investment_pnl_entries_admin_manager_select" ON public.apartment_investment_pnl_entries;

CREATE POLICY "apartment_investment_pnl_entries_admin_manager_select"
  ON public.apartment_investment_pnl_entries
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      public.is_tenant_admin_or_manager()
      AND EXISTS (
        SELECT 1 FROM public.apartments a
        WHERE a.id = apartment_investment_pnl_entries.apartment_id
          AND a.tenant_id = public.my_tenant_id()
          AND a.deleted_at IS NULL
      )
    )
  );

COMMENT ON POLICY "apartment_investment_pnl_entries_admin_manager_select" ON public.apartment_investment_pnl_entries IS
  'SELECT: super_admin nebo admin/manager v rámci tenanta bytu.';

DROP POLICY IF EXISTS "apartment_investment_pnl_entries_admin_manager_delete" ON public.apartment_investment_pnl_entries;

CREATE POLICY "apartment_investment_pnl_entries_admin_manager_delete"
  ON public.apartment_investment_pnl_entries
  FOR DELETE
  TO authenticated
  USING (
    public.is_super_admin()
    OR (
      public.is_tenant_admin_or_manager()
      AND EXISTS (
        SELECT 1 FROM public.apartments a
        WHERE a.id = apartment_investment_pnl_entries.apartment_id
          AND a.tenant_id = public.my_tenant_id()
          AND a.deleted_at IS NULL
      )
    )
  );

COMMENT ON POLICY "apartment_investment_pnl_entries_admin_manager_delete" ON public.apartment_investment_pnl_entries IS
  'DELETE: super_admin nebo admin/manager – mazání záznamů (support), ne úprava částek.';

NOTIFY pgrst, 'reload schema';
