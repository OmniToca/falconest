-- =============================================================================
-- FalcoNest – tenant_ui_preferences: brandové barvy UI + Timestamp Merging
-- =============================================================================
-- PROČ: Server jako zdroj pravdy pro primary/secondary barvy agentury; updated_at
-- v UTC umožní klientům offline-first sync bez slepého přepsání novějšího stavu.
-- ADDITIVE: nová tabulka + RLS; existující lokální local_ui_preferences v klientovi se nemění.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Tabulka
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.tenant_ui_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  primary_color text,
  secondary_color text,
  updated_at timestamp with time zone NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  CONSTRAINT tenant_ui_preferences_tenant_id_key UNIQUE (tenant_id)
);

COMMENT ON TABLE public.tenant_ui_preferences IS
  'Nastavení vzhledu aplikace na úrovni tenanta (barvy); updated_at pro Timestamp Merging při synchronizaci z klienta.';

COMMENT ON COLUMN public.tenant_ui_preferences.tenant_id IS
  'Agentura (firma); FK na tenants.';

COMMENT ON COLUMN public.tenant_ui_preferences.primary_color IS
  'Primární barva v HEX textu (např. #1E3A8A); NULL = výchozí paleta aplikace.';

COMMENT ON COLUMN public.tenant_ui_preferences.secondary_color IS
  'Sekundární / akcentová barva v HEX textu; NULL = výchozí paleta aplikace.';

COMMENT ON COLUMN public.tenant_ui_preferences.updated_at IS
  'Čas poslední změny řádku v UTC; klient při merge porovnává s lokální kopií.';

-- PROČ: UNIQUE(tenant_id) výše vytvoří implicitní index – další index na stejném sloupci netřeba.

-- -----------------------------------------------------------------------------
-- 2) RLS – čte celý tenant; zapisuje jen admin/manager (+ Super Admin)
-- -----------------------------------------------------------------------------

ALTER TABLE public.tenant_ui_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_ui_preferences_select ON public.tenant_ui_preferences;
CREATE POLICY tenant_ui_preferences_select
  ON public.tenant_ui_preferences
  FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

DROP POLICY IF EXISTS tenant_ui_preferences_insert ON public.tenant_ui_preferences;
CREATE POLICY tenant_ui_preferences_insert
  ON public.tenant_ui_preferences
  FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

DROP POLICY IF EXISTS tenant_ui_preferences_update ON public.tenant_ui_preferences;
CREATE POLICY tenant_ui_preferences_update
  ON public.tenant_ui_preferences
  FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

-- PROČ: Smazání řádku by znamenalo „žádný záznam“ – klient může interpretovat jako výchozí barvy;
-- není nutné povolovat DELETE všem; zatím bez politiky DELETE (tvrdé mazání jen přes service_role / dashboard).

-- -----------------------------------------------------------------------------
-- 3) Oprávnění role authenticated (řádky stále filtruje RLS)
-- -----------------------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE ON public.tenant_ui_preferences TO authenticated;
