-- =============================================================================
-- FalcoNest – Více přiřazených pracovníků na jeden úkol
-- =============================================================================
-- PROČ: Agentury potřebují na jeden úkol (např. velký úklid) přiřadit VÍCE
-- zaměstnanců najednou. Úkol se zobrazí v kalendáři všem přiřazeným. V budoucnu
-- budeme celkovou odměnu dělit počtem těchto pracovníků.
-- assigned_to zůstává pro hlavního pracovníka – Additive Development.
-- =============================================================================

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS assigned_user_ids uuid[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN public.tasks.assigned_user_ids IS 'Další přiřazení pracovníci – pro sdílení úkolu a dělení odměny. Hlavní pracovník zůstává v assigned_to.';

CREATE INDEX IF NOT EXISTS idx_tasks_assigned_user_ids
  ON public.tasks USING GIN (assigned_user_ids)
  WHERE assigned_user_ids IS NOT NULL AND array_length(assigned_user_ids, 1) > 0;
