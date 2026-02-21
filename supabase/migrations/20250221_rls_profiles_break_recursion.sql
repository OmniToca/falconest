-- =============================================================================
-- FalcoNest – ROZBITÍ REKURZE NA PROFILES (42P17) – jeden skript
-- =============================================================================
-- Spusť v Supabase SQL Editoru. Po spuštění znovu otestuj přihlášení.
-- Tabulka app_super_admins má sloupec "id" (PK). Pokud máš "user_id", nahraď v bodě 1 a 4.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Naplnění app_super_admins (pokud běžíš jako role s přístupem k profiles)
-- -----------------------------------------------------------------------------
INSERT INTO public.app_super_admins (id)
SELECT id FROM public.profiles WHERE role = 'super_admin'
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 2. Odstranění VŠECH RLS policy na public.profiles
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "profiles_select_own_or_super"    ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_own"             ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_super_admin"     ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own_or_super"     ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own_or_super"     ON public.profiles;
DROP POLICY IF EXISTS "profiles_delete_super_only"      ON public.profiles;

-- -----------------------------------------------------------------------------
-- 3. Odstranění staré funkce (CASCADE smaže závislé objekty – např. policy jinde)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.is_super_admin() CASCADE;

-- -----------------------------------------------------------------------------
-- 4. Nová funkce – čte JEN z app_super_admins, NIKDY z profiles
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.app_super_admins WHERE id = auth.uid());
$$;

COMMENT ON FUNCTION public.is_super_admin() IS 'Pouze app_super_admins. Nepoužívá profiles → žádná rekurze.';

-- -----------------------------------------------------------------------------
-- 5. Znovu vytvoření RLS policy na profiles
-- -----------------------------------------------------------------------------
-- Read Own: přihlášení – každý čte svůj řádek
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

-- Read All if Super Admin: super_admin vidí všechny řádky
CREATE POLICY "profiles_select_super_admin"
  ON public.profiles FOR SELECT
  USING (public.is_super_admin());

-- INSERT / UPDATE / DELETE (jako v původním návrhu)
CREATE POLICY "profiles_insert_own_or_super"
  ON public.profiles FOR INSERT
  WITH CHECK (id = auth.uid() OR public.is_super_admin());

CREATE POLICY "profiles_update_own_or_super"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid() OR public.is_super_admin());

CREATE POLICY "profiles_delete_super_only"
  ON public.profiles FOR DELETE
  USING (public.is_super_admin());

-- =============================================================================
-- POZNÁMKA: DROP FUNCTION ... CASCADE mohl smazat policy na tenants, apartments,
-- reservations, tasks. Pokud po tomto skriptu selhávají dotazy na tyto tabulky,
-- znovu spusť příslušné CREATE POLICY z migrace 20250218_rls_multi_tenant.sql
-- (sekce 3–6).
-- =============================================================================
