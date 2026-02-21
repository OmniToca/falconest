-- =============================================================================
-- FalcoNest – tabulky modules a tenant_modules + RLS pro Super Admin
-- =============================================================================
-- modules = katalog dostupných modulů (finance, warehouse, dashboard, …).
-- tenant_modules = které moduly má tenant zapnuté (vazba tenant_id + module_id).
-- Super Admin smí na obou tabulkách SELECT/INSERT/UPDATE/DELETE.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka modules (katalog) – pokud neexistuje
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  name text NOT NULL,
  sort_order int NOT NULL DEFAULT 0,
  price numeric(10,2)
);

COMMENT ON TABLE public.modules IS 'Katalog modulů (funkcí) – finance, warehouse, dashboard, apartments, …';
COMMENT ON COLUMN public.modules.key IS 'Identifikátor pro aplikaci, např. finance, warehouse.';
COMMENT ON COLUMN public.modules.sort_order IS 'Pořadí zobrazení v menu.';

-- RLS: všichni přihlášení mohou číst moduly (katalog); měnit smí jen super_admin.
ALTER TABLE public.modules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "modules_select_all" ON public.modules;
CREATE POLICY "modules_select_all"
  ON public.modules FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "modules_insert_super" ON public.modules;
CREATE POLICY "modules_insert_super"
  ON public.modules FOR INSERT
  WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS "modules_update_super" ON public.modules;
CREATE POLICY "modules_update_super"
  ON public.modules FOR UPDATE
  USING (public.is_super_admin());

DROP POLICY IF EXISTS "modules_delete_super" ON public.modules;
CREATE POLICY "modules_delete_super"
  ON public.modules FOR DELETE
  USING (public.is_super_admin());

-- -----------------------------------------------------------------------------
-- 2. Tabulka tenant_modules (vazba tenant ↔ modul)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tenant_modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  module_id uuid NOT NULL REFERENCES public.modules(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active',
  UNIQUE (tenant_id, module_id)
);

COMMENT ON TABLE public.tenant_modules IS 'Které moduly má tenant aktivní. Super Admin zde zapíná/vypíná moduly.';
COMMENT ON COLUMN public.tenant_modules.status IS 'active = zapnuto, cancelled = zrušeno (pro budoucí rozšíření).';

CREATE INDEX IF NOT EXISTS idx_tenant_modules_tenant_id ON public.tenant_modules(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_modules_module_id ON public.tenant_modules(module_id);

-- RLS: Super Admin vše; běžný uživatel jen čte řádky svého tenanta (pro zobrazení menu).
ALTER TABLE public.tenant_modules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tenant_modules_select" ON public.tenant_modules;
CREATE POLICY "tenant_modules_select"
  ON public.tenant_modules FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

DROP POLICY IF EXISTS "tenant_modules_insert_super" ON public.tenant_modules;
CREATE POLICY "tenant_modules_insert_super"
  ON public.tenant_modules FOR INSERT
  WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS "tenant_modules_update_super" ON public.tenant_modules;
CREATE POLICY "tenant_modules_update_super"
  ON public.tenant_modules FOR UPDATE
  USING (public.is_super_admin());

DROP POLICY IF EXISTS "tenant_modules_delete_super" ON public.tenant_modules;
CREATE POLICY "tenant_modules_delete_super"
  ON public.tenant_modules FOR DELETE
  USING (public.is_super_admin());
