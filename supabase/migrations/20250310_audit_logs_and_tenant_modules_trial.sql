-- Audit log pro sledování akcí uživatelů a trial sloupce v tenant_modules (self-service premium).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka public.audit_logs
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action_type text NOT NULL,
  table_name text,
  record_id text,
  details jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.audit_logs IS 'Audit záznamy akcí uživatelů (aktivace modulů, změny atd.).';
COMMENT ON COLUMN public.audit_logs.action_type IS 'Typ akce, např. MODULE_ACTIVATED.';
COMMENT ON COLUMN public.audit_logs.details IS 'Volitelný JSON s detaily (module key, price, trial, …).';

CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant_id ON public.audit_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Čtení: vlastní tenant nebo super_admin.
DROP POLICY IF EXISTS "audit_logs_select" ON public.audit_logs;
CREATE POLICY "audit_logs_select"
  ON public.audit_logs FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

-- Zápis: přihlášený uživatel (pro vlastní akce); tenant_id musí odpovídat profilu.
DROP POLICY IF EXISTS "audit_logs_insert" ON public.audit_logs;
CREATE POLICY "audit_logs_insert"
  ON public.audit_logs FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND (tenant_id IS NULL OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1))
  );

-- -----------------------------------------------------------------------------
-- 2. Rozšíření public.tenant_modules o trial
-- -----------------------------------------------------------------------------
ALTER TABLE public.tenant_modules
  ADD COLUMN IF NOT EXISTS is_trial boolean NOT NULL DEFAULT false;

ALTER TABLE public.tenant_modules
  ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz;

COMMENT ON COLUMN public.tenant_modules.is_trial IS 'Aktivace jako zkušební období (např. 14 dní).';
COMMENT ON COLUMN public.tenant_modules.trial_ends_at IS 'Konec zkušební doby (UTC).';

-- Self-service: tenant smí přidat modul pro svůj tenant (např. start trialu).
DROP POLICY IF EXISTS "tenant_modules_insert_own_tenant" ON public.tenant_modules;
CREATE POLICY "tenant_modules_insert_own_tenant"
  ON public.tenant_modules FOR INSERT
  WITH CHECK (
    tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

-- UPDATE vlastního tenanta (např. prodloužení trialu) – pouze vlastní řádky.
DROP POLICY IF EXISTS "tenant_modules_update_own_tenant" ON public.tenant_modules;
CREATE POLICY "tenant_modules_update_own_tenant"
  ON public.tenant_modules FOR UPDATE
  USING (
    tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  )
  WITH CHECK (
    tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );
