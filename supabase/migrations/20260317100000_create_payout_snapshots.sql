-- =============================================================================
-- FalcoNest – Tabulka payout_snapshots pro zmraženou historii výplat
-- =============================================================================
-- PROČ: Historické výplaty nesmí záviset na dynamickém dotazu do task_payouts/
-- task_commissions (hrozí změna historických dat). Při uzamčení měsíce se uloží
-- neměnný snapshot – stejný princip jako billing_snapshots u fakturace.
--
-- Jeden řádek = jeden příjemce (zaměstnanec nebo partner) za jeden měsíc.
-- items_data = uzamčený seznam úkolů, za které dostal zaplaceno (pro PDF a UI).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka payout_snapshots
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payout_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  payout_period date NOT NULL,
  is_employee boolean NOT NULL,
  profile_id uuid REFERENCES public.profiles(id) ON DELETE RESTRICT,
  client_id uuid REFERENCES public.clients(id) ON DELETE RESTRICT,
  recipient_name text NOT NULL,
  total_amount numeric NOT NULL,
  items_data jsonb NOT NULL DEFAULT '[]',
  locked_at timestamp with time zone NOT NULL DEFAULT now(),
  locked_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  CONSTRAINT payout_snapshots_recipient_check CHECK (
    (is_employee = true  AND profile_id IS NOT NULL AND client_id IS NULL)
    OR (is_employee = false AND client_id IS NOT NULL AND profile_id IS NULL)
  )
);

COMMENT ON TABLE public.payout_snapshots IS 'Zmražená historie výplat – jeden řádek na příjemce a měsíc. Čtení pro Historie výplat a PDF export.';
COMMENT ON COLUMN public.payout_snapshots.payout_period IS 'První den měsíce – např. 2026-03-01.';
COMMENT ON COLUMN public.payout_snapshots.is_employee IS 'true = zaměstnanec (profile_id), false = partner (client_id).';
COMMENT ON COLUMN public.payout_snapshots.recipient_name IS 'Jméno příjemce v okamžiku uzamčení (denormalizované).';
COMMENT ON COLUMN public.payout_snapshots.items_data IS 'Pole objektů: [{ "task_id", "task_title", "date", "amount" }, ...].';
COMMENT ON COLUMN public.payout_snapshots.locked_by IS 'Profil (Admin), který uzamčení provedl.';

-- Unikátní index – jeden snapshot na příjemce a měsíc (employee i partner rozlišeni).
CREATE UNIQUE INDEX IF NOT EXISTS idx_payout_snapshots_tenant_period_recipient
  ON public.payout_snapshots (
    tenant_id,
    payout_period,
    COALESCE(profile_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(client_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

CREATE INDEX IF NOT EXISTS idx_payout_snapshots_tenant_period
  ON public.payout_snapshots(tenant_id, payout_period);

-- -----------------------------------------------------------------------------
-- 2. RLS
-- -----------------------------------------------------------------------------
ALTER TABLE public.payout_snapshots ENABLE ROW LEVEL SECURITY;

-- SELECT: Admin/Manager/Worker v rámci tenantu; Super Admin vše.
CREATE POLICY "payout_snapshots_select_tenant"
  ON public.payout_snapshots FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

-- INSERT: Pouze Admin v rámci tenantu; locked_by = aktuální profil.
CREATE POLICY "payout_snapshots_insert_admin"
  ON public.payout_snapshots FOR INSERT
  WITH CHECK (
    (public.is_super_admin() OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    ))
    AND locked_by = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

-- UPDATE/DELETE: Snapshoty jsou immutable (stejně jako billing_snapshots).
-- Lze později přidat policy pro super_admin při opravě chyb.
