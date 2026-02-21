-- =============================================================================
-- FalcoNest – diagnostika RLS a app_super_admins (jen čtení, nic nemění)
-- =============================================================================
-- Spusť v Supabase SQL Editoru. Ověří: počet v app_super_admins, tvoje ID,
-- a seznam všech policy na tenants, tasks, apartments, reservations, profiles.
-- =============================================================================

-- 1) Počet řádků a obsah app_super_admins (mělo by tam být tvoje ID)
SELECT 'app_super_admins' AS tabulka, count(*) AS pocet_radku FROM public.app_super_admins;

SELECT id AS super_admin_user_id, 'V tomto seznamu by mělo být tvoje ID' AS poznamka
FROM public.app_super_admins
ORDER BY id;

-- 2) Seznam všech RLS policy na klíčových tabulkách
SELECT
  schemaname,
  tablename,
  policyname,
  cmd AS operace,
  permissive
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('tenants', 'tasks', 'apartments', 'reservations', 'profiles')
ORDER BY tablename, policyname;

-- 3) Přehled: které tabulky mají RLS zapnuté a kolik mají policy
SELECT
  c.relname AS tabulka,
  c.relrowsecurity AS rls_zapnuto,
  (SELECT count(*) FROM pg_policies p WHERE p.tablename = c.relname AND p.schemaname = 'public') AS pocet_policy
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
WHERE c.relkind = 'r'
  AND c.relname IN ('tenants', 'tasks', 'apartments', 'reservations', 'profiles', 'app_super_admins')
ORDER BY c.relname;
