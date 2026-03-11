-- FalcoNest – Soft-Unassign: historický kontext při automatickém odebírání úkolů (dovolená/výpověď).
-- Umožňuje v UI zobrazit „Původně přiřazený: Carlos“ bez parsování Audit Logu.
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS unassigned_info jsonb;

COMMENT ON COLUMN public.tasks.unassigned_info IS 'Při automatickém odebrání (absence, konec smlouvy): previous_id, previous_name, unassigned_at. Při novém přiřazení se vymaže na null.';
