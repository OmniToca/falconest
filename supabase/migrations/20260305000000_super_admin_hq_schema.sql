-- =============================================================================
-- FalcoNest HQ (Super-Admin) – rozšíření schématu pro správu B2B SaaS
-- =============================================================================
-- Blueprint: hierarchie (super_admin / account_manager), Lovec vs. Farmář u tenantů,
-- audit zásahů podpory (Magic Login), měsíční provize pro Account Managery.
-- ADDITIVE: pouze ALTER a nové tabulky, nic nemazáme.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. TENANTS – Lovec (acquired_by) a Farmář (managed_by)
-- -----------------------------------------------------------------------------
-- PROČ: Každá úklidová firma má evidovat, kdo ji získal (Lovec) a kdo se o ni
-- aktuálně stará (Farmář). Oba jsou interní zaměstnanci (vazba na profiles).
-- ON DELETE SET NULL: při smazání profilu neztratíme tenanta, jen odpojíme vazbu.

ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS acquired_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS managed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.tenants.acquired_by IS 'Lovec – profil zaměstnance, který agenturu získal (kdo přivedl klienta).';
COMMENT ON COLUMN public.tenants.managed_by IS 'Farmář – profil zaměstnance, který se o agenturu aktuálně stará (obchodní podpora).';

CREATE INDEX IF NOT EXISTS idx_tenants_acquired_by ON public.tenants(acquired_by);
CREATE INDEX IF NOT EXISTS idx_tenants_managed_by ON public.tenants(managed_by);

-- -----------------------------------------------------------------------------
-- 2. SUPPORT_INTERVENTIONS – výkazy práce / audit zásahů podpory
-- -----------------------------------------------------------------------------
-- PROČ: Account manageři se mohou přepnout do pohledu klienta (Magic Login).
-- Každý takový zásah musí být auditován: kdo, u koho, kdy začal, kdy skončil,
-- textový výkaz práce (co přesně řešil). Tabulka je globální (HQ), ne tenant-scoped.

CREATE TABLE IF NOT EXISTS public.support_interventions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Kdo zasahoval (Account Manager nebo Super-Admin)
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  -- U jakého tenanta (agentury) probíhal zásah
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  -- Časový rozsah zásahu
  started_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  ended_at timestamptz,
  -- Výkaz práce – co přesně bylo řešeno (audit pro měsíční provize)
  work_report text,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

COMMENT ON TABLE public.support_interventions IS 'Zásahy podpory (Magic Login) – audit kdo, u kterého tenanta, kdy a co řešil. Pro výkazy práce a měsíční provize.';
COMMENT ON COLUMN public.support_interventions.profile_id IS 'Profil zaměstnance, který zasahoval (Account Manager / Super-Admin).';
COMMENT ON COLUMN public.support_interventions.tenant_id IS 'Agentura (tenant), u které probíhal zásah.';
COMMENT ON COLUMN public.support_interventions.started_at IS 'Začátek zásahu (přepnutí do pohledu klienta).';
COMMENT ON COLUMN public.support_interventions.ended_at IS 'Konec zásahu (odhlášení z pohledu klienta); NULL = stále probíhá.';
COMMENT ON COLUMN public.support_interventions.work_report IS 'Textový výkaz práce – co bylo řešeno (pro Super-Admina při schvalování provizí).';

CREATE INDEX IF NOT EXISTS idx_support_interventions_profile_id ON public.support_interventions(profile_id);
CREATE INDEX IF NOT EXISTS idx_support_interventions_tenant_id ON public.support_interventions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_support_interventions_started_at ON public.support_interventions(started_at DESC);

ALTER TABLE public.support_interventions ENABLE ROW LEVEL SECURITY;

-- RLS: Super-Admin vidí vše; Account Manager jen své vlastní zásahy (profile_id = jeho profil).
CREATE POLICY "support_interventions_select"
  ON public.support_interventions FOR SELECT
  USING (
    public.is_super_admin()
    OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "support_interventions_insert"
  ON public.support_interventions FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "support_interventions_update"
  ON public.support_interventions FOR UPDATE
  USING (
    public.is_super_admin()
    OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  )
  WITH CHECK (
    public.is_super_admin()
    OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "support_interventions_delete"
  ON public.support_interventions FOR DELETE
  USING (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- 3. AGENCY_MANAGEMENT_SETTLEMENTS – měsíční provize pro Lovce a Farmáře
-- -----------------------------------------------------------------------------
-- PROČ: Super-Admin na konci měsíce ručně zadá/schválí provizi pro Account Managery
-- (Lovce a Farmáře). Žádné automatické připisování – vždy schválení člověkem.
-- Jeden řádek = jedna schválená provize pro jednoho příjemce za jednu agenturu za jeden měsíc.

CREATE TABLE IF NOT EXISTS public.agency_management_settlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Komu je provize určena (Lovec nebo Farmář – profil zaměstnance)
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  -- Za kterou agenturu (tenant) se provize vztahuje
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  -- Období vyúčtování – první den měsíce (např. 2026-03-01)
  settlement_period date NOT NULL,
  -- Typ: provize za získání (Lovec) nebo za správu (Farmář)
  role_type text NOT NULL CHECK (role_type IN ('hunter', 'farmer')),
  -- Schválená částka v měně platformy (např. EUR)
  amount numeric NOT NULL CHECK (amount >= 0),
  -- Stav: pending = navrženo, approved = schváleno Super-Adminem, paid = vyplaceno
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'paid')),
  -- Kdo a kdy schválil (Super-Admin)
  approved_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  -- Jeden příjemce, jedna agentura, jedno období, jeden typ – max jeden záznam
  UNIQUE (profile_id, tenant_id, settlement_period, role_type)
);

COMMENT ON TABLE public.agency_management_settlements IS 'Měsíční vyúčtování provizí pro Account Managery (Lovec/Farmář). Super-Admin ručně schvaluje.';
COMMENT ON COLUMN public.agency_management_settlements.profile_id IS 'Příjemce provize – profil Lovce nebo Farmáře.';
COMMENT ON COLUMN public.agency_management_settlements.tenant_id IS 'Agentura, za kterou se provize vyplácí.';
COMMENT ON COLUMN public.agency_management_settlements.settlement_period IS 'První den měsíce vyúčtování (např. 2026-03-01).';
COMMENT ON COLUMN public.agency_management_settlements.role_type IS 'hunter = Lovec (získal klienta), farmer = Farmář (stará se o klienta).';
COMMENT ON COLUMN public.agency_management_settlements.approved_by IS 'Profil Super-Admina, který provizi schválil.';

CREATE INDEX IF NOT EXISTS idx_agency_management_settlements_profile_id ON public.agency_management_settlements(profile_id);
CREATE INDEX IF NOT EXISTS idx_agency_management_settlements_tenant_id ON public.agency_management_settlements(tenant_id);
CREATE INDEX IF NOT EXISTS idx_agency_management_settlements_period ON public.agency_management_settlements(settlement_period DESC);

ALTER TABLE public.agency_management_settlements ENABLE ROW LEVEL SECURITY;

-- RLS: Super-Admin vidí a spravuje vše; Account Manager vidí jen své vlastní provize (profile_id = jeho profil).
CREATE POLICY "agency_management_settlements_select"
  ON public.agency_management_settlements FOR SELECT
  USING (
    public.is_super_admin()
    OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

-- Vkládat a měnit smí jen Super-Admin (schvalování provizí).
CREATE POLICY "agency_management_settlements_insert"
  ON public.agency_management_settlements FOR INSERT
  WITH CHECK (public.is_super_admin());

CREATE POLICY "agency_management_settlements_update"
  ON public.agency_management_settlements FOR UPDATE
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

CREATE POLICY "agency_management_settlements_delete"
  ON public.agency_management_settlements FOR DELETE
  USING (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- 4. Oprávnění pro roli authenticated
-- -----------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON public.support_interventions TO authenticated;
GRANT DELETE ON public.support_interventions TO authenticated;

GRANT SELECT ON public.agency_management_settlements TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.agency_management_settlements TO authenticated;
