-- =============================================================================
-- FalcoNest – Tabulka task_categories pro dynamické barvy a ikony typů úkolů
-- =============================================================================
-- Multi-tenant. Každý tenant definuje vlastní kategorie (code, color_hex, icon_name).
-- RLS vynucuje izolaci podle tenant_id.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.task_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  code text NOT NULL,
  color_hex text NOT NULL,
  icon_name text,
  order_index integer DEFAULT 0,
  deleted_at timestamptz,
  UNIQUE(tenant_id, code)
);

-- Ind pro rychlé vyhledání podle tenant_id a soft delete
CREATE INDEX IF NOT EXISTS idx_task_categories_tenant_active
  ON public.task_categories(tenant_id)
  WHERE deleted_at IS NULL;

-- RLS zapnout
ALTER TABLE public.task_categories ENABLE ROW LEVEL SECURITY;

-- Politika SELECT – jen vlastní tenant nebo super_admin
CREATE POLICY "task_categories_select"
  ON public.task_categories FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth.uid() = profiles.auth_id LIMIT 1)
  );

-- Politika INSERT – tenant_id musí odpovídat přihlášenému tenantu
CREATE POLICY "task_categories_insert"
  ON public.task_categories FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth.uid() = profiles.auth_id LIMIT 1)
  );

-- Politika UPDATE – jen vlastní tenant
CREATE POLICY "task_categories_update"
  ON public.task_categories FOR UPDATE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth.uid() = profiles.auth_id LIMIT 1)
  );

-- Politika DELETE – jen vlastní tenant
CREATE POLICY "task_categories_delete"
  ON public.task_categories FOR DELETE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth.uid() = profiles.auth_id LIMIT 1)
  );

-- Seed výchozích kategorií pro existující tenanty (volitelné – lze spustit ručně)
-- INSERT do task_categories pro každý tenant podle potřeby.
