-- =============================================================================
-- P1 výkon: kompozitní indexy na tasks pro měsíční / ops filtry
-- =============================================================================
-- PROČ (audit): Admin načítá úkoly podle tenant_id + scheduled_start / completed_at.
-- Samostatný idx_tasks_tenant_id nestačí – bez (tenant_id, scheduled_start) Postgres
-- často skenuje široký tenant slice. Indexy jsou aditivní (IF NOT EXISTS).
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_tasks_tenant_scheduled_start
  ON public.tasks (tenant_id, scheduled_start)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_tenant_completed_at
  ON public.tasks (tenant_id, completed_at)
  WHERE deleted_at IS NULL;

COMMENT ON INDEX public.idx_tasks_tenant_scheduled_start IS
  'P1: měsíční Kanban / dashboard / ops okno – filtr tenant + scheduled_start.';

COMMENT ON INDEX public.idx_tasks_tenant_completed_at IS
  'P1: otevřené vs nedávno dokončené úkoly – filtr tenant + completed_at.';
