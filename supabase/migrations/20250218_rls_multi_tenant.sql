-- =============================================================================
-- FalcoNest – RLS (Row Level Security) pro multi-tenant architekturu
-- =============================================================================
-- Kompatibilní s Flutter kódem: Super Admin (tenant_id NULL) vidí vše,
-- běžný uživatel jen data své agentury. Přihlášení vyžaduje čtení VLASTNÍHO profilu.
--
-- Spusť v Supabase SQL Editoru (Dashboard → SQL Editor) nebo přes supabase db push.
-- Před spuštěním doporučeno: záloha DB. Po zapnutí RLS ověř přihlášení Super Admina i Admina.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Funkce is_super_admin() – BEZ ZACYKLENÍ (no recursion)
-- -----------------------------------------------------------------------------
-- Musí být SECURITY DEFINER: při kontrole RLS na profiles by jinak volání
-- "SELECT role FROM profiles WHERE id = auth.uid()" znovu spustilo RLS na profiles → rekurze.
-- DEFINER = funkce běží s oprávněním vlastníka (obchází RLS při čtení profiles).

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT (SELECT role FROM public.profiles WHERE id = auth.uid() LIMIT 1) = 'super_admin';
$$;

COMMENT ON FUNCTION public.is_super_admin() IS 'Vrací true, pokud aktuální uživatel má v profiles role = super_admin. Pouze pro RLS policies – SECURITY DEFINER zamezí rekurzi.';

-- -----------------------------------------------------------------------------
-- 2. PROFILES – uživatel MUSÍ přečíst svůj vlastní řádek (login)
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- SELECT: Vlastní profil (přihlášení!) NEBO super_admin vidí všechny.
CREATE POLICY "profiles_select_own_or_super"
  ON public.profiles FOR SELECT
  USING (id = auth.uid() OR public.is_super_admin());

-- INSERT: Vlastní záznam (registrace / onboarding) NEBO super_admin.
CREATE POLICY "profiles_insert_own_or_super"
  ON public.profiles FOR INSERT
  WITH CHECK (id = auth.uid() OR public.is_super_admin());

-- UPDATE: Vlastní záznam (úprava profilu) NEBO super_admin (správa všech).
CREATE POLICY "profiles_update_own_or_super"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid() OR public.is_super_admin());

-- DELETE: Pouze super_admin smí mazat profily.
CREATE POLICY "profiles_delete_super_only"
  ON public.profiles FOR DELETE
  USING (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- 3. TENANTS – super_admin vše, běžný uživatel jen svůj tenant
-- -----------------------------------------------------------------------------
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

-- SELECT: Super_admin vidí všechny; jinak jen řádek, kde tenants.id = můj profiles.tenant_id.
CREATE POLICY "tenants_select"
  ON public.tenants FOR SELECT
  USING (
    public.is_super_admin()
    OR id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

-- INSERT / UPDATE / DELETE: Jen super_admin (správa agentur).
CREATE POLICY "tenants_insert_super"
  ON public.tenants FOR INSERT
  WITH CHECK (public.is_super_admin());

CREATE POLICY "tenants_update_super"
  ON public.tenants FOR UPDATE
  USING (public.is_super_admin());

CREATE POLICY "tenants_delete_super"
  ON public.tenants FOR DELETE
  USING (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- 4. APARTMENTS – super_admin vše, jinak jen byty své agentury
-- -----------------------------------------------------------------------------
ALTER TABLE public.apartments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "apartments_select"
  ON public.apartments FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "apartments_insert"
  ON public.apartments FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "apartments_update"
  ON public.apartments FOR UPDATE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "apartments_delete"
  ON public.apartments FOR DELETE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

-- -----------------------------------------------------------------------------
-- 5. RESERVATIONS – nemají tenant_id; vazba přes apartment_id → apartments.tenant_id
-- -----------------------------------------------------------------------------
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reservations_select"
  ON public.reservations FOR SELECT
  USING (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.apartments a
      WHERE a.id = reservations.apartment_id
        AND a.tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
    )
  );

CREATE POLICY "reservations_insert"
  ON public.reservations FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.apartments a
      WHERE a.id = reservations.apartment_id
        AND a.tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
    )
  );

CREATE POLICY "reservations_update"
  ON public.reservations FOR UPDATE
  USING (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.apartments a
      WHERE a.id = reservations.apartment_id
        AND a.tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
    )
  );

CREATE POLICY "reservations_delete"
  ON public.reservations FOR DELETE
  USING (
    public.is_super_admin()
    OR EXISTS (
      SELECT 1 FROM public.apartments a
      WHERE a.id = reservations.apartment_id
        AND a.tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
    )
  );

-- -----------------------------------------------------------------------------
-- 6. TASKS – mají tenant_id
-- -----------------------------------------------------------------------------
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tasks_select"
  ON public.tasks FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "tasks_insert"
  ON public.tasks FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "tasks_update"
  ON public.tasks FOR UPDATE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

CREATE POLICY "tasks_delete"
  ON public.tasks FOR DELETE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

-- =============================================================================
-- POZNÁMKY
-- =============================================================================
-- • Tabulky invitations, staff_absences, user_roles: pokud máš RLS zapnuté jinde,
--   ujisti se, že policies používají public.is_super_admin() a že nedochází
--   k rekurzi (např. user_roles dříve četl role z profiles – po zapnutí RLS
--   na profiles použij is_super_admin() místo (SELECT role FROM profiles ...).
-- • Super Admin má v profiles tenant_id = NULL – policies to nevadí;
--   (SELECT tenant_id FROM profiles ...) u něj vrátí NULL a podmínky
--   "tenant_id = NULL" neprojdou, ale is_super_admin() = true, takže vidí vše.
-- • Flutter aplikace filtruje na klientovi podle tenantIdForData (Super Admin
--   = vybraná agentura v paměti), takže i při plném přístupu v DB zobrazuje
--   jen data jedné agentury.
-- =============================================================================
