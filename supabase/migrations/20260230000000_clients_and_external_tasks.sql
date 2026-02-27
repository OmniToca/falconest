-- =============================================================================
-- FalcoNest – CRM Klienti a podpora Externích úkolů (Fáze 1 – Databáze)
-- =============================================================================
-- PROČ: Pro zavedení "Externích úkolů" (např. transfery pro cizí lidi bez apartmánu)
-- musíme přejít na architekturu orientovanou na Klienta (client). Úkoly bez bytu
-- by jinak rozbily finance a reporty. V této fázi připravujeme pouze SQL fundament.
--
-- POZNÁMKA: apartment_id je již NULLABLE z migrace 20260225100000.
-- Tabulku apartment_owners nemažeme – zůstává vedle nové struktury.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka clients (Zákazníci agentury)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  email text,
  phone text,
  client_type text,
  created_at timestamp with time zone DEFAULT now(),
  deleted_at timestamp with time zone
);

COMMENT ON TABLE public.clients IS 'Zákazníci agentury – majitelé (owner), externí klienti (external), agentury (agency). Pro fakturaci úkolů bez bytu.';
COMMENT ON COLUMN public.clients.client_type IS 'Typ klienta: owner, external, agency.';
COMMENT ON COLUMN public.clients.deleted_at IS 'Soft delete; NULL = aktivní záznam.';

-- Index pro RLS a časté filtry podle tenanta
CREATE INDEX IF NOT EXISTS idx_clients_tenant_id ON public.clients(tenant_id);
CREATE INDEX IF NOT EXISTS idx_clients_deleted_at ON public.clients(deleted_at) WHERE deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- 2. Úpravy tabulky tasks (apartment_id již nullable z předchozí migrace)
-- -----------------------------------------------------------------------------
-- client_id – vazba na klienta pro fakturaci úkolů bez bytu
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS client_id uuid REFERENCES public.clients(id) ON DELETE SET NULL;

-- custom_location – adresa pro řidiče/personál u úkolů bez bytu
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS custom_location text;

-- custom_title – název úkolu, např. "Transfer letiště", když nemáme název bytu
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS custom_title text;

COMMENT ON COLUMN public.tasks.client_id IS 'FK na clients – pro externí úkoly bez apartment_id (fakturace klientovi).';
COMMENT ON COLUMN public.tasks.custom_location IS 'Adresa pro řidiče/personál u úkolů bez bytu.';
COMMENT ON COLUMN public.tasks.custom_title IS 'Název úkolu pro externí úkoly – např. "Transfer letiště".';

-- -----------------------------------------------------------------------------
-- 3. RLS pro tabulku clients
-- -----------------------------------------------------------------------------
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

-- SELECT: Uživatel vidí pouze klienty svého tenanta
CREATE POLICY "clients_select"
  ON public.clients FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

-- INSERT: Uživatel smí vkládat pouze klienty svého tenanta
CREATE POLICY "clients_insert"
  ON public.clients FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

-- UPDATE: Uživatel smí upravovat pouze klienty svého tenanta
CREATE POLICY "clients_update"
  ON public.clients FOR UPDATE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

-- DELETE: Uživatel smí mazat pouze klienty svého tenanta
CREATE POLICY "clients_delete"
  ON public.clients FOR DELETE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );
