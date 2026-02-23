-- =============================================================================
-- FalcoNest – Priorita plánování pro Smart Planner (generátor úkolů)
-- =============================================================================
-- Sloupec planning_priority určuje pořadí, ve kterém se úkoly přiřazují personálu.
-- Nižší číslo = vyšší priorita (Svaté úkoly jdou první: check-in, check-out, transfery).
-- Úklidy a údržba (flexibilní) mohou být posouvány v čase při kolizi.
-- =============================================================================

ALTER TABLE public.task_categories
  ADD COLUMN IF NOT EXISTS planning_priority integer NOT NULL DEFAULT 99;

-- Komentář pro dokumentaci
COMMENT ON COLUMN public.task_categories.planning_priority IS 'Priorita plánování: 1=Svaté (check-in/out, transfery), 10=cleaning, 20=maintenance, 30=extra. Nižší číslo = dřívější přiřazení.';

-- Nastavení priorit podle code – Svaté úkoly (1), Úklid (10), Údržba (20), Extra (30)
UPDATE public.task_categories SET planning_priority = 1
  WHERE LOWER(TRIM(code)) IN ('check_in', 'check_out', 'transfer_in', 'transfer_out');

UPDATE public.task_categories SET planning_priority = 10
  WHERE LOWER(TRIM(code)) = 'cleaning';

UPDATE public.task_categories SET planning_priority = 20
  WHERE LOWER(TRIM(code)) = 'maintenance';

UPDATE public.task_categories SET planning_priority = 30
  WHERE LOWER(TRIM(code)) = 'extra';
