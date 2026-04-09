-- =============================================================================
-- FalcoNest – oprava RLS policy tenant_modules_select_own_tenant
-- =============================================================================
-- PROBLÉM: Policy používala profiles.id = auth.uid(), ale v profiles je
-- uživatel identifikován sloupcem auth_id (odkaz na auth.users.id), ne id
-- (UUID profilu). Podmínka tedy nikdy neseděla pro běžné uživatele.
--
-- ŘEŠENÍ: SELECT vlastního tenanta má používat auth_id = auth.uid().
-- Čtení modulů pro sidebar zajišťuje i policy tenant_modules_select
-- (my_tenant_id()), tato oprava sjednocuje obě policy na správný vzor.
-- =============================================================================

DROP POLICY IF EXISTS "tenant_modules_select_own_tenant" ON public.tenant_modules;

CREATE POLICY "tenant_modules_select_own_tenant"
  ON public.tenant_modules
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

COMMENT ON POLICY "tenant_modules_select_own_tenant" ON public.tenant_modules IS
  'SELECT: běžný uživatel vidí řádky tenant_modules svého tenanta (auth_id = auth.uid()).';
