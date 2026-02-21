-- =============================================================================
-- FalcoNest – Unified Profiles ("Ghost Profile" Strategy)
-- =============================================================================
-- Kontext: Každý zaměstnanec (Active i Pending) má záznam v profiles.
-- Pending: status='pending', auth_id=NULL.
-- Active: status='active', auth_id=UUID (propojeno s auth.users).
--
-- VAROVÁNÍ: Destruktivní migrace – maže data v profiles, invitations, tasks.
-- Pouze pro dev režim. Před spuštěním záloha DB!
-- PO MIGRACI: Vytvoř první Super Admin ručně (profiles s role=super_admin, auth_id=UUID).
-- Spusť v Supabase SQL Editoru.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Drop závislé objekty (triggery, RLS, FKs)
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS sync_app_super_admins_trigger ON public.profiles;

-- FK z tasks na profiles/auth
ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS tasks_assigned_to_fkey;

-- user_roles závisí na profiles
DROP TABLE IF EXISTS public.user_roles CASCADE;

-- staff_absences závisí na profiles a invitations
ALTER TABLE public.staff_absences DROP CONSTRAINT IF EXISTS staff_absences_profile_id_fkey;
ALTER TABLE public.staff_absences DROP CONSTRAINT IF EXISTS staff_absences_invitation_id_fkey;

-- -----------------------------------------------------------------------------
-- 2. Vyčištění tabulek (pořadí kvůli FK)
-- -----------------------------------------------------------------------------
TRUNCATE public.tasks CASCADE;
TRUNCATE public.staff_absences CASCADE;
TRUNCATE public.invitations CASCADE;
TRUNCATE public.profiles CASCADE;

-- Vyprázdnění app_super_admins (sync se znovu naplní po vytvoření profilů)
TRUNCATE public.app_super_admins CASCADE;

-- -----------------------------------------------------------------------------
-- 3. Přejmenování / záloha původní profiles (Supabase vytváří profiles automaticky)
-- DROP a CREATE – Supabase Dashboard málokdy má "čistou" profiles bez id=auth.uid().
-- Používáme DROP CASCADE – profile tabulka se smaže včetně všech referencí.
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS public.profiles CASCADE;

-- -----------------------------------------------------------------------------
-- 4. Nová tabulka profiles – Ghost Profile Strategy
-- -----------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  email text,
  first_name text,
  last_name text,
  name text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pending')),
  tenant_id uuid REFERENCES public.tenants(id) ON DELETE CASCADE,
  role text DEFAULT 'worker',
  roles text[] DEFAULT '{}',
  weekly_hours int DEFAULT 40,
  start_date date,
  end_date date,
  language_code text DEFAULT 'cs',
  preferred_currency text DEFAULT 'CZK',
  last_sign_in_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.profiles IS 'Jednotný zdroj pravdy pro zaměstnance. Pending: auth_id=NULL, status=pending. Active: auth_id propojen s auth.users.';
COMMENT ON COLUMN public.profiles.auth_id IS 'Propojení s auth.users(id). NULL = pending (čekající na registraci).';
COMMENT ON COLUMN public.profiles.status IS 'active = přihlášen, pending = čeká na registraci (ghost profile).';
COMMENT ON COLUMN public.profiles.email IS 'E-mail – pro párování pozvánek a registrace.';

CREATE INDEX IF NOT EXISTS profiles_auth_id_idx ON public.profiles(auth_id);
CREATE INDEX IF NOT EXISTS profiles_tenant_id_idx ON public.profiles(tenant_id);
CREATE INDEX IF NOT EXISTS profiles_status_idx ON public.profiles(status);
CREATE UNIQUE INDEX IF NOT EXISTS profiles_email_tenant_uniq ON public.profiles(email, tenant_id) WHERE email IS NOT NULL AND tenant_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 5. Aktualizace app_super_admins sync triggeru – používá auth_id
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_app_super_admins()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.role = 'super_admin' AND NEW.auth_id IS NOT NULL THEN
    INSERT INTO public.app_super_admins (id) VALUES (NEW.auth_id)
    ON CONFLICT (id) DO NOTHING;
  ELSIF (TG_OP = 'UPDATE' AND OLD.role = 'super_admin' AND (NEW.role IS NULL OR NEW.role <> 'super_admin' OR NEW.auth_id IS DISTINCT FROM OLD.auth_id)) THEN
    IF OLD.auth_id IS NOT NULL THEN
      DELETE FROM public.app_super_admins WHERE id = OLD.auth_id;
    END IF;
  ELSIF TG_OP = 'DELETE' AND OLD.role = 'super_admin' AND OLD.auth_id IS NOT NULL THEN
    DELETE FROM public.app_super_admins WHERE id = OLD.auth_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER sync_app_super_admins_trigger
  AFTER INSERT OR UPDATE OF role, auth_id OR DELETE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_app_super_admins();

-- -----------------------------------------------------------------------------
-- 6. Tasks – přísný FK na profiles(id)
-- -----------------------------------------------------------------------------
-- assigned_to může být TEXT (starší schema) – konvertovat na UUID před FK
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'tasks' AND column_name = 'assigned_to'
      AND data_type = 'text'
  ) THEN
    ALTER TABLE public.tasks
      ALTER COLUMN assigned_to TYPE uuid
      USING CASE
        WHEN assigned_to IS NULL OR TRIM(assigned_to) = '' THEN NULL
        ELSE assigned_to::uuid
      END;
  END IF;
END $$;

ALTER TABLE public.tasks
  ADD CONSTRAINT tasks_assigned_to_fkey
  FOREIGN KEY (assigned_to) REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.tasks.assigned_to IS 'FK na profiles.id – aktivní i pending zaměstnanci (ghost profiles).';

-- -----------------------------------------------------------------------------
-- 7. Invitations – přidat profile_id pro propojení s ghost profilem
-- -----------------------------------------------------------------------------
ALTER TABLE public.invitations ADD COLUMN IF NOT EXISTS profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE;
COMMENT ON COLUMN public.invitations.profile_id IS 'Propojení s ghost profilem – vytvořen při pozvání.';

-- -----------------------------------------------------------------------------
-- 8. RLS na profiles – auth_id místo id
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- SELECT: vlastní řádek (auth_id = auth.uid()) NEBO super_admin NEBO profily ve svém tenantu
CREATE POLICY "profiles_select"
  ON public.profiles FOR SELECT
  USING (
    auth_id = auth.uid()
    OR public.is_super_admin()
    OR tenant_id = (SELECT p.tenant_id FROM public.profiles p WHERE p.auth_id = auth.uid() LIMIT 1)
  );

-- INSERT: super_admin nebo admin vlastního tenanta (pro ghost profily při pozvání)
CREATE POLICY "profiles_insert"
  ON public.profiles FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (auth_id IS NULL AND tenant_id = (SELECT p.tenant_id FROM public.profiles p WHERE p.auth_id = auth.uid() LIMIT 1))
    OR auth_id = auth.uid()
  );

-- UPDATE: vlastní řádek nebo super_admin
CREATE POLICY "profiles_update"
  ON public.profiles FOR UPDATE
  USING (auth_id = auth.uid() OR public.is_super_admin())
  WITH CHECK (auth_id = auth.uid() OR public.is_super_admin());

-- DELETE: pouze super_admin
CREATE POLICY "profiles_delete"
  ON public.profiles FOR DELETE
  USING (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- 9. Funkce pro získání tenant_id aktuálního uživatele (SECURITY DEFINER – obchází RLS)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1;
$$;

COMMENT ON FUNCTION public.my_tenant_id() IS 'Vrací tenant_id aktuálního uživatele. Pro RLS policies.';

-- -----------------------------------------------------------------------------
-- 10. Aktualizace RLS na tenants, apartments, reservations, tasks – auth_id místo id
-- -----------------------------------------------------------------------------
-- tenants_select
DROP POLICY IF EXISTS "tenants_select" ON public.tenants;
CREATE POLICY "tenants_select" ON public.tenants FOR SELECT
  USING (public.is_super_admin() OR id = public.my_tenant_id());

-- apartments_select, insert, update, delete
DROP POLICY IF EXISTS "apartments_select" ON public.apartments;
CREATE POLICY "apartments_select" ON public.apartments FOR SELECT
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

DROP POLICY IF EXISTS "apartments_insert" ON public.apartments;
CREATE POLICY "apartments_insert" ON public.apartments FOR INSERT
  WITH CHECK (public.is_super_admin() OR tenant_id = public.my_tenant_id());

DROP POLICY IF EXISTS "apartments_update" ON public.apartments;
CREATE POLICY "apartments_update" ON public.apartments FOR UPDATE
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

DROP POLICY IF EXISTS "apartments_delete" ON public.apartments;
CREATE POLICY "apartments_delete" ON public.apartments FOR DELETE
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

-- reservations (přes apartments.tenant_id)
DROP POLICY IF EXISTS "reservations_select" ON public.reservations;
CREATE POLICY "reservations_select" ON public.reservations FOR SELECT
  USING (public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.apartments a
    WHERE a.id = reservations.apartment_id AND a.tenant_id = public.my_tenant_id()
  ));

-- tasks
DROP POLICY IF EXISTS "tasks_select" ON public.tasks;
CREATE POLICY "tasks_select" ON public.tasks FOR SELECT
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

DROP POLICY IF EXISTS "tasks_insert" ON public.tasks;
CREATE POLICY "tasks_insert" ON public.tasks FOR INSERT
  WITH CHECK (public.is_super_admin() OR tenant_id = public.my_tenant_id());

DROP POLICY IF EXISTS "tasks_update" ON public.tasks;
CREATE POLICY "tasks_update" ON public.tasks FOR UPDATE
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

DROP POLICY IF EXISTS "tasks_delete" ON public.tasks;
CREATE POLICY "tasks_delete" ON public.tasks FOR DELETE
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

-- tenant_modules (pokud existuje)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'tenant_modules' AND policyname LIKE '%tenant%') THEN
    EXECUTE 'DROP POLICY IF EXISTS "tenant_modules_select" ON public.tenant_modules';
    EXECUTE 'CREATE POLICY "tenant_modules_select" ON public.tenant_modules FOR SELECT
      USING (public.is_super_admin() OR tenant_id = public.my_tenant_id())';
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 11. TRIGGER: Při registraci (auth.users insert) propoj ghost profile
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_email text;
  p record;
BEGIN
  user_email := NEW.email;
  IF user_email IS NULL OR user_email = '' THEN
    RETURN NEW;
  END IF;

  -- Existuje ghost profile s tímto emailem? (tenant_id může být NULL pro organickou registraci)
  FOR p IN
    SELECT id, tenant_id FROM public.profiles
    WHERE LOWER(email) = LOWER(user_email) AND status = 'pending' AND auth_id IS NULL
    ORDER BY tenant_id NULLS LAST
    LIMIT 1
  LOOP
    UPDATE public.profiles
    SET auth_id = NEW.id, status = 'active', updated_at = now()
    WHERE id = p.id;
    RETURN NEW;
  END LOOP;

  RETURN NEW;
END;
$$;

-- Supabase volá tuto funkci přes Database Webhook nebo můžeme použít Edge Function.
-- Alternativa: Trigger na auth.users – Supabase Auth schema je v auth, ne public.
-- Trigger na auth.users vyžaduje oprávnění na auth schema.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

COMMENT ON FUNCTION public.handle_new_user() IS 'Při registraci: propojí ghost profile (pending) s novým auth.users záznamem podle emailu.';
