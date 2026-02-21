-- =============================================================================
-- FalcoNest – totální vyčištění RLS policies na profiles (včetně „zombie“)
-- =============================================================================
-- Smaže VŠECHNY policy na public.profiles (dynamicky z pg_policies),
-- pak vytvoří jen ty správné. Funkci is_super_admin() neměň.
-- Spusť v Supabase SQL Editoru.
-- =============================================================================

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', r.policyname);
  END LOOP;
END
$$;

-- Znovu vytvoření pouze správných policy na profiles
CREATE POLICY "profiles_select_own_or_super"
  ON public.profiles FOR SELECT
  USING (id = auth.uid() OR public.is_super_admin());

CREATE POLICY "profiles_insert_own_or_super"
  ON public.profiles FOR INSERT
  WITH CHECK (id = auth.uid() OR public.is_super_admin());

CREATE POLICY "profiles_update_own_or_super"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid() OR public.is_super_admin())
  WITH CHECK (id = auth.uid() OR public.is_super_admin());

CREATE POLICY "profiles_delete_super_only"
  ON public.profiles FOR DELETE
  USING (public.is_super_admin());
