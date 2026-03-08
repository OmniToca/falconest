-- =============================================================================
-- FalcoNest HQ Tým – Krok 1: Datová vrstva (additivní)
-- =============================================================================
-- 1) Tabulka hq_staff_contracts – smluvní parametry a odměny pro členy HQ.
-- 2) RLS pro hq_staff_contracts (Super-Admin vše; obchoďák čte vlastní smlouvu).
-- 3) RLS úprava staff_absences – umožnit HQ členům číst/vytvářet vlastní absence
--    s tenant_id IS NULL (dovolené bez vazby na agenturu).
-- ADDITIVE: pouze nová tabulka a úpravy politik, nic nemazáme z byznys dat.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka hq_staff_contracts
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hq_staff_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  employment_type text NOT NULL DEFAULT 'hpp' CHECK (employment_type IN ('hpp', 'ico')),
  position_label text,
  fixed_salary_monthly numeric CHECK (fixed_salary_monthly IS NULL OR fixed_salary_monthly >= 0),
  bonus_per_acquired_agency numeric CHECK (bonus_per_acquired_agency IS NULL OR bonus_per_acquired_agency >= 0),
  commission_percent_managed numeric CHECK (commission_percent_managed IS NULL OR (commission_percent_managed >= 0 AND commission_percent_managed <= 100)),
  valid_from date NOT NULL DEFAULT CURRENT_DATE,
  valid_to date,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  CONSTRAINT hq_staff_contracts_valid_range CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

COMMENT ON TABLE public.hq_staff_contracts IS 'Smluvní parametry a odměny pro členy HQ týmu (Obchoďák, Účetní, Podpora). Jeden profil může mít více řádků – historie smluv.';
COMMENT ON COLUMN public.hq_staff_contracts.profile_id IS 'Profil člena HQ (profiles.id).';
COMMENT ON COLUMN public.hq_staff_contracts.employment_type IS 'hpp = pracovní poměr, ico = IČO / DPČ.';
COMMENT ON COLUMN public.hq_staff_contracts.position_label IS 'Pozice pro zobrazení (Účetní, Mzdová, Obchoďák, Podpora, …).';
COMMENT ON COLUMN public.hq_staff_contracts.valid_from IS 'První den platnosti smlouvy.';
COMMENT ON COLUMN public.hq_staff_contracts.valid_to IS 'Poslední den platnosti; NULL = stále platná.';

CREATE INDEX IF NOT EXISTS idx_hq_staff_contracts_profile_id ON public.hq_staff_contracts(profile_id);
CREATE INDEX IF NOT EXISTS idx_hq_staff_contracts_valid ON public.hq_staff_contracts(valid_from, valid_to);

-- Trigger: automatická aktualizace updated_at při UPDATE (stejný vzor jako tasks).
CREATE OR REPLACE FUNCTION public.set_hq_staff_contracts_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := (now() AT TIME ZONE 'utc');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS hq_staff_contracts_updated_at_trigger ON public.hq_staff_contracts;
CREATE TRIGGER hq_staff_contracts_updated_at_trigger
  BEFORE UPDATE ON public.hq_staff_contracts
  FOR EACH ROW
  EXECUTE FUNCTION public.set_hq_staff_contracts_updated_at();

-- -----------------------------------------------------------------------------
-- 2. RLS pro hq_staff_contracts
-- -----------------------------------------------------------------------------
ALTER TABLE public.hq_staff_contracts ENABLE ROW LEVEL SECURITY;

-- SELECT: Super-Admin vidí vše; jinak uživatel jen vlastní smlouvy (profile_id = jeho profil).
CREATE POLICY "hq_staff_contracts_select"
  ON public.hq_staff_contracts FOR SELECT
  USING (
    public.is_super_admin()
    OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

-- INSERT, UPDATE, DELETE: pouze Super-Admin.
CREATE POLICY "hq_staff_contracts_insert"
  ON public.hq_staff_contracts FOR INSERT
  WITH CHECK (public.is_super_admin());

CREATE POLICY "hq_staff_contracts_update"
  ON public.hq_staff_contracts FOR UPDATE
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

CREATE POLICY "hq_staff_contracts_delete"
  ON public.hq_staff_contracts FOR DELETE
  USING (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- 3. RLS pro staff_absences (HQ dovolené: tenant_id IS NULL, vlastní profile_id)
-- -----------------------------------------------------------------------------
-- Odstraníme všechny stávající politiky na staff_absences (pokud existují),
-- pak vytvoříme nové včetně větve pro HQ (tenant_id IS NULL a vlastní profil).
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'staff_absences')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.staff_absences', r.policyname);
  END LOOP;
END $$;

-- Zajistíme, že RLS je zapnuté (idempotentní).
ALTER TABLE public.staff_absences ENABLE ROW LEVEL SECURITY;

-- SELECT: Super-Admin vše; řádky svého tenanta (agentury); NEBO vlastní HQ absence (tenant_id IS NULL a profile_id = já).
CREATE POLICY "staff_absences_select"
  ON public.staff_absences FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
    OR (
      tenant_id IS NULL
      AND profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
    )
  );

-- INSERT: Super-Admin; admin/manager tenantu pro řádky s tenant_id = jejich tenant; NEBO vlastní HQ absence (tenant_id IS NULL, profile_id = já).
CREATE POLICY "staff_absences_insert"
  ON public.staff_absences FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id IS NOT NULL
      AND tenant_id = public.my_tenant_id()
    )
    OR (
      tenant_id IS NULL
      AND profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
    )
  );

-- UPDATE: stejná pravidla jako SELECT (můžu měnit řádky, které vidím).
CREATE POLICY "staff_absences_update"
  ON public.staff_absences FOR UPDATE
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
    OR (
      tenant_id IS NULL
      AND profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
    OR (
      tenant_id IS NULL
      AND profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
    )
  );

-- DELETE: stejně jako SELECT.
CREATE POLICY "staff_absences_delete"
  ON public.staff_absences FOR DELETE
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
    OR (
      tenant_id IS NULL
      AND profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
    )
  );

COMMENT ON POLICY "staff_absences_select" ON public.staff_absences IS 'SELECT: super_admin vše; tenant vidí absence svého tenanta; HQ člen vidí vlastní absence (tenant_id IS NULL).';
COMMENT ON POLICY "staff_absences_insert" ON public.staff_absences IS 'INSERT: super_admin; tenant pro svůj tenant_id; HQ člen pro vlastní absence (tenant_id NULL, profile_id = já).';
COMMENT ON POLICY "staff_absences_update" ON public.staff_absences IS 'UPDATE: stejné jako SELECT – měnit smím jen to, co vidím.';
COMMENT ON POLICY "staff_absences_delete" ON public.staff_absences IS 'DELETE: stejné jako SELECT.';

-- -----------------------------------------------------------------------------
-- 4. Oprávnění pro roli authenticated
-- -----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON public.hq_staff_contracts TO authenticated;
