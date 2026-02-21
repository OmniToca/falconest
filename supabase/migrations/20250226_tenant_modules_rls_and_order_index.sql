-- =============================================================================
-- FalcoNest – oprava RLS na tenant_modules (Super Admin plný přístup) + řazení modulů
-- =============================================================================
-- 1. Jedna politika FOR ALL pro is_super_admin() na tenant_modules.
-- 2. Sloupec order_index v modules + nastavení pořadí 1–9.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. FIX RLS na tenant_modules – jedna politika pro Super Admin (SELECT, INSERT, UPDATE, DELETE)
-- -----------------------------------------------------------------------------
ALTER TABLE public.tenant_modules ENABLE ROW LEVEL SECURITY;

-- Odstranit všechny stávající policy na tenant_modules
DROP POLICY IF EXISTS "tenant_modules_select" ON public.tenant_modules;
DROP POLICY IF EXISTS "tenant_modules_insert_super" ON public.tenant_modules;
DROP POLICY IF EXISTS "tenant_modules_update_super" ON public.tenant_modules;
DROP POLICY IF EXISTS "tenant_modules_delete_super" ON public.tenant_modules;

-- Super Admin má plný přístup; běžný uživatel musí vidět řádky svého tenanta (menu).
-- Policy 1: Super Admin ALL (SELECT, INSERT, UPDATE, DELETE)
CREATE POLICY "tenant_modules_super_admin_full"
  ON public.tenant_modules
  FOR ALL
  TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- Policy 2: Běžný uživatel jen SELECT vlastního tenanta (pro sidebar / menu)
CREATE POLICY "tenant_modules_select_own_tenant"
  ON public.tenant_modules
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = (SELECT tenant_id FROM public.profiles WHERE id = auth.uid() LIMIT 1)
  );

-- -----------------------------------------------------------------------------
-- 2. Řazení modulů – sloupec order_index
-- -----------------------------------------------------------------------------
ALTER TABLE public.modules ADD COLUMN IF NOT EXISTS order_index integer DEFAULT 99;

COMMENT ON COLUMN public.modules.order_index IS 'Logické pořadí v menu (1 = první, 99 = na konec).';

-- Nastavení pořadí: 1 Dashboard, 2 Apartments, 3 Reservations, 4 Tasks, 5 Staff, 6 Warehouse, 7 Finance, 8 Smart Lock, 9 Automation
UPDATE public.modules SET order_index = 1  WHERE key = 'dashboard';
UPDATE public.modules SET order_index = 2  WHERE key = 'apartments';
UPDATE public.modules SET order_index = 3  WHERE key = 'reservations';
UPDATE public.modules SET order_index = 4  WHERE key = 'tasks';
UPDATE public.modules SET order_index = 5  WHERE key = 'staff';
UPDATE public.modules SET order_index = 6  WHERE key = 'warehouse';
UPDATE public.modules SET order_index = 7  WHERE key = 'finance';
UPDATE public.modules SET order_index = 8  WHERE key = 'smart_lock';
UPDATE public.modules SET order_index = 9  WHERE key = 'automation';
