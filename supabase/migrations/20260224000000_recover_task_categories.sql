-- =============================================================================
-- FalcoNest – Obnova smazané tabulky task_categories (GLOBAL DICTIONARY)
-- =============================================================================
-- Tabulka je platformový globální číselník – bez tenant_id. Kategorie sdílené
-- pro celou platformu. Spravuje majitel FalcoNestu (Super Admin).
-- =============================================================================

-- DDL: Vytvoření tabulky
CREATE TABLE IF NOT EXISTS public.task_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  color_hex text NOT NULL,
  icon_name text,
  order_index integer DEFAULT 0,
  planning_priority integer NOT NULL DEFAULT 99
);

COMMENT ON TABLE public.task_categories IS 'Globální číselník typů úkolů – barvy, ikony, priorita plánování. Bez tenant_id.';
COMMENT ON COLUMN public.task_categories.planning_priority IS 'Priorita plánování: 1=Svaté (check-in/out, transfery), 10=cleaning, 20=maintenance, 30=extra. Nižší číslo = dřívější přiřazení.';

-- RLS
ALTER TABLE public.task_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "task_categories_select" ON public.task_categories;
CREATE POLICY "task_categories_select"
  ON public.task_categories FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "task_categories_insert" ON public.task_categories;
CREATE POLICY "task_categories_insert"
  ON public.task_categories FOR INSERT
  WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS "task_categories_update" ON public.task_categories;
CREATE POLICY "task_categories_update"
  ON public.task_categories FOR UPDATE
  USING (public.is_super_admin());

DROP POLICY IF EXISTS "task_categories_delete" ON public.task_categories;
CREATE POLICY "task_categories_delete"
  ON public.task_categories FOR DELETE
  USING (public.is_super_admin());

-- Seed: systémové kategorie se správnými planning_priority
INSERT INTO public.task_categories (code, color_hex, icon_name, order_index, planning_priority)
VALUES
  ('cleaning',     '#F3E5F5', 'cleaning_services',       0, 10),
  ('transfer_in',   '#E3F2FD', 'directions_car',          1,  1),
  ('transfer_out',  '#E3F2FD', 'directions_car',          2,  1),
  ('check_in',     '#FFF3E0', 'key',                      3,  1),
  ('check_out',    '#FFF3E0', 'key',                      4,  1),
  ('maintenance',  '#FFEBEE', 'warning_amber_rounded',   5, 20),
  ('extra',        '#E8E8E8', 'miscellaneous_services',  6, 30)
ON CONFLICT (code) DO UPDATE SET
  color_hex = EXCLUDED.color_hex,
  icon_name = EXCLUDED.icon_name,
  order_index = EXCLUDED.order_index,
  planning_priority = EXCLUDED.planning_priority;
