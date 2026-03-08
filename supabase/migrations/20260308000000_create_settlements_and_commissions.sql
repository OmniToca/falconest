-- =============================================================================
-- FalcoNest – Modul Vyúčtování a Provize (Settlements & Commissions)
-- =============================================================================
-- PROČ: Nový prémiový modul pro výdaje agentury – výplaty zaměstnancům a
-- provize externím partnerům z jednotlivých úkolů. ZCELA ODDĚLENÝ od stávajících
-- Podkladů pro fakturaci (které fakturují klientům).
--
-- Additive Development: stávající tabulky tasks ani fakturační logiku neměň.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka task_payouts (Výplaty pracovníkům)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.task_payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  amount numeric NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'paid')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.task_payouts IS 'Výplaty pracovníkům z úkolů – modul Vyúčtování a Provize. Odděleno od fakturace klientům.';
COMMENT ON COLUMN public.task_payouts.profile_id IS 'Komu se platí – FK na profiles (zaměstnanec).';
COMMENT ON COLUMN public.task_payouts.amount IS 'Částka výplaty v měně tenanta.';
COMMENT ON COLUMN public.task_payouts.status IS 'pending = čeká na schválení, approved = schváleno, paid = vyplaceno.';

CREATE INDEX IF NOT EXISTS idx_task_payouts_tenant_id ON public.task_payouts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_task_payouts_task_id ON public.task_payouts(task_id);
CREATE INDEX IF NOT EXISTS idx_task_payouts_profile_id ON public.task_payouts(profile_id);
CREATE INDEX IF NOT EXISTS idx_task_payouts_status ON public.task_payouts(status);

-- -----------------------------------------------------------------------------
-- 2. Tabulka task_commissions (Provize partnerům)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.task_commissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
  amount numeric NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'paid')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.task_commissions IS 'Provize externím partnerům (agenturám) z úkolů – modul Vyúčtování a Provize.';
COMMENT ON COLUMN public.task_commissions.client_id IS 'Externí agentura/partner v CRM – komu platíme provizi. FK na clients.';
COMMENT ON COLUMN public.task_commissions.amount IS 'Částka provize v měně tenanta.';
COMMENT ON COLUMN public.task_commissions.status IS 'pending = čeká na schválení, approved = schváleno, paid = vyplaceno.';

CREATE INDEX IF NOT EXISTS idx_task_commissions_tenant_id ON public.task_commissions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_task_commissions_task_id ON public.task_commissions(task_id);
CREATE INDEX IF NOT EXISTS idx_task_commissions_client_id ON public.task_commissions(client_id);
CREATE INDEX IF NOT EXISTS idx_task_commissions_status ON public.task_commissions(status);

-- -----------------------------------------------------------------------------
-- 3. RLS – task_payouts
-- -----------------------------------------------------------------------------
ALTER TABLE public.task_payouts ENABLE ROW LEVEL SECURITY;

-- SELECT: Admin vidí vše v tenantu, Pracovník vidí jen své výplaty (profile_id = jeho profil).
CREATE POLICY "task_payouts_select"
  ON public.task_payouts FOR SELECT
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND (
        (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
        OR profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
      )
    )
  );

-- INSERT/UPDATE/DELETE: Pouze Admin v rámci tenantu.
CREATE POLICY "task_payouts_insert"
  ON public.task_payouts FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  );

CREATE POLICY "task_payouts_update"
  ON public.task_payouts FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  );

CREATE POLICY "task_payouts_delete"
  ON public.task_payouts FOR DELETE
  USING (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  );

-- -----------------------------------------------------------------------------
-- 4. RLS – task_commissions (Pouze Admin)
-- -----------------------------------------------------------------------------
ALTER TABLE public.task_commissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "task_commissions_select"
  ON public.task_commissions FOR SELECT
  USING (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  );

CREATE POLICY "task_commissions_insert"
  ON public.task_commissions FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  );

CREATE POLICY "task_commissions_update"
  ON public.task_commissions FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  );

CREATE POLICY "task_commissions_delete"
  ON public.task_commissions FOR DELETE
  USING (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    )
  );
