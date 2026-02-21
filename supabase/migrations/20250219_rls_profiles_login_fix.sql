-- =============================================================================
-- FalcoNest – oprava přihlášení s RLS (profiles SELECT)
-- =============================================================================
-- Problém: Jediná policy "profiles_select_own_or_super" vyhodnocuje
--   (id = auth.uid() OR public.is_super_admin()).
-- V některých situacích (pořadí vyhodnocení, nebo auth.uid() ještě null
-- při prvním requestu po signIn) může dojít k tomu, že uživatel nedostane
-- vlastní řádek.
--
-- Řešení: Rozdělit SELECT na DVĚ policy:
--   1) Čtení VLASTNÍHO profilu: pouze (id = auth.uid()) – bez volání is_super_admin().
--   2) Super admin vidí všechny: pouze is_super_admin().
-- Tak se při čtení vlastního řádku nevolá is_super_admin() a auth.uid() stačí.
-- =============================================================================

-- Odstranit původní sloučenou policy
DROP POLICY IF EXISTS "profiles_select_own_or_super" ON public.profiles;

-- 1) Každý uživatel smí číst SVŮJ vlastní řádek (přihlášení). Žádná jiná podmínka.
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

-- 2) Super admin smí číst všechny řádky.
CREATE POLICY "profiles_select_super_admin"
  ON public.profiles FOR SELECT
  USING (public.is_super_admin());
