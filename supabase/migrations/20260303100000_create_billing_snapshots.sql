-- =============================================================================
-- FalcoNest – Tabulka billing_snapshots pro zmražená vyúčtování majitelů
-- =============================================================================
-- PROČ: Místo generování a ukládání fyzických PDF souborů při uzamčení měsíce
-- ukládáme přesná data (ceny, úkoly, výdaje) jako JSONB. Majitelé si z těchto
-- dat mohou v Klientské zóně kdykoliv vygenerovat PDF On-Demand.
--
-- Vztah: billing_snapshots.client_id → clients.id (majitel = klient ve fakturaci).
-- RLS: Admin/Worker vidí snapshoty své agentury; Majitel (property_owner) pouze
-- své vlastní (kde client.profile_id = jeho profil).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka billing_snapshots
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.billing_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  billing_period date NOT NULL,
  snapshot_data jsonb NOT NULL,
  locked_at timestamp with time zone NOT NULL DEFAULT now(),
  locked_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT
);

COMMENT ON TABLE public.billing_snapshots IS 'Zmražená vyúčtování – JSONB snapshot úkolů, cen a nákladů. Majitel si z něj generuje PDF On-Demand v Klientské zóně.';
COMMENT ON COLUMN public.billing_snapshots.billing_period IS 'První den měsíce – např. 2026-02-01.';
COMMENT ON COLUMN public.billing_snapshots.snapshot_data IS 'Zmražená struktura: items (úkoly), total_to_invoice, total_expenses, final_to_invoice, client_name, currency.';
COMMENT ON COLUMN public.billing_snapshots.locked_by IS 'Profil (Admin) který uzamčení provedl.';

-- Unikátní index – jeden snapshot na klienta a měsíc.
CREATE UNIQUE INDEX IF NOT EXISTS idx_billing_snapshots_tenant_client_period
  ON public.billing_snapshots(tenant_id, client_id, billing_period);

-- Index pro dotazy majitele a admin přehledu.
CREATE INDEX IF NOT EXISTS idx_billing_snapshots_tenant_period
  ON public.billing_snapshots(tenant_id, billing_period);
CREATE INDEX IF NOT EXISTS idx_billing_snapshots_client_id
  ON public.billing_snapshots(client_id);

-- -----------------------------------------------------------------------------
-- 2. RLS politiky
-- -----------------------------------------------------------------------------
ALTER TABLE public.billing_snapshots ENABLE ROW LEVEL SECURITY;

-- SELECT Admin/Worker: Zaměstnanci agentury (NE property_owner) vidí snapshoty své agentury.
-- property_owner smí vidět pouze přes vlastní client_id (policy níže).
CREATE POLICY "billing_snapshots_select_tenant"
  ON public.billing_snapshots FOR SELECT
  USING (
    public.is_super_admin()
    OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) != 'property_owner'
      AND tenant_id = public.my_tenant_id()
    )
  );

-- SELECT Owner: Majitel (property_owner) vidí POUZE snapshoty, kde jeho profil je napojen na client_id.
-- clients.profile_id = profiles.id; majitel přihlášen jako auth.uid() → profiles.auth_id.
CREATE POLICY "billing_snapshots_select_owner"
  ON public.billing_snapshots FOR SELECT
  USING (
    client_id IN (
      SELECT id FROM public.clients
      WHERE profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
      AND deleted_at IS NULL
    )
  );

-- INSERT: Pouze Admin (role = 'admin') v rámci svého tenant_id může vytvářet snapshoty.
-- locked_by musí odpovídat profilu vkladajícího uživatele.
CREATE POLICY "billing_snapshots_insert_admin"
  ON public.billing_snapshots FOR INSERT
  WITH CHECK (
    (public.is_super_admin() OR (
      (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'admin'
      AND tenant_id = public.my_tenant_id()
    ))
    AND locked_by = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

-- UPDATE/DELETE: Snapshoty jsou immutable – žádná politika (ani super_admin nemění historická data).
-- Pro budoucí rozšíření (oprava chyb) lze přidat policy pro super_admin nebo admin.
