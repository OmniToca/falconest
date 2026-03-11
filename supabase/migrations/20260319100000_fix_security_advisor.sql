-- =============================================================================
-- FalcoNest – Oprava bezpečnostních výstrah Supabase Security Advisor
-- =============================================================================
-- 1. RLS DISABLED: zapnutí RLS na invitations a cron_edge_config + politiky
-- 2. RLS POLICY ALWAYS TRUE: zpřísnění UPDATE politiky na user_devices
-- 3. FUNCTION SEARCH PATH: nastavení search_path u funkcí (bez změny logiky)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1a. INVITATIONS – zapnutí RLS a tenant-based politiky
-- -----------------------------------------------------------------------------
-- Pozvánky: admin tenantu vidí/řídí jen pozvánky své agentury (tenant_id).
-- Super Admin vidí vše včetně HQ pozvánek (tenant_id IS NULL).
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "invitations_select" ON public.invitations;
CREATE POLICY "invitations_select"
  ON public.invitations FOR SELECT
  USING (
    public.is_super_admin()
    OR (tenant_id IS NOT NULL AND tenant_id = public.my_tenant_id())
  );

DROP POLICY IF EXISTS "invitations_insert" ON public.invitations;
CREATE POLICY "invitations_insert"
  ON public.invitations FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

DROP POLICY IF EXISTS "invitations_update" ON public.invitations;
CREATE POLICY "invitations_update"
  ON public.invitations FOR UPDATE
  USING (
    public.is_super_admin()
    OR (tenant_id IS NOT NULL AND tenant_id = public.my_tenant_id())
  );

DROP POLICY IF EXISTS "invitations_delete" ON public.invitations;
CREATE POLICY "invitations_delete"
  ON public.invitations FOR DELETE
  USING (
    public.is_super_admin()
    OR (tenant_id IS NOT NULL AND tenant_id = public.my_tenant_id())
  );

COMMENT ON TABLE public.invitations IS 'Pozvánky do týmu. RLS: admin vidí jen pozvánky své agentury; Super Admin vše.';

-- -----------------------------------------------------------------------------
-- 1b. CRON_EDGE_CONFIG – zapnutí RLS, přístup jen service_role (bez politik)
-- -----------------------------------------------------------------------------
-- Žádná politika pro authenticated/anon = žádný přístup z aplikace.
-- service_role v Supabase RLS obchází, takže cron/backend dál funguje.
ALTER TABLE public.cron_edge_config ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- 2. USER_DEVICES – zpřísnění UPDATE: pouze vlastní řádky (odstranění USING (true))
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "user_devices_update" ON public.user_devices;

CREATE POLICY "user_devices_update"
  ON public.user_devices FOR UPDATE
  USING (
    public.is_super_admin()
    OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
      AND tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
    )
  );

-- -----------------------------------------------------------------------------
-- 3. FUNCTION SEARCH PATH – immutable search_path pro bezpečnost
-- -----------------------------------------------------------------------------
ALTER FUNCTION public.set_tasks_updated_at() SET search_path = public;
ALTER FUNCTION public.set_hq_staff_contracts_updated_at() SET search_path = public;
ALTER FUNCTION public.invoke_template_reminders() SET search_path = public;
ALTER FUNCTION public.my_tenant_id() SET search_path = public;

-- Funkce bez public. prefixu v původní migraci – v PostgreSQL je v public schématu
ALTER FUNCTION public.check_reservation_overlap_with_cleaning() SET search_path = public;
