-- =============================================================================
-- FalcoNest – Přidání sloupců pro sledování reálného času práce (Time Tracking)
-- =============================================================================
-- started_at = UTC čas zahájení úkolu (při přechodu do in_progress)
-- completed_at = UTC čas dokončení úkolu (při přechodu do completed)
-- =============================================================================

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS started_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;

COMMENT ON COLUMN public.tasks.started_at IS 'Reálný čas zahájení práce (UTC) – nastaví se při přechodu do in_progress.';
COMMENT ON COLUMN public.tasks.completed_at IS 'Reálný čas dokončení úkolu (UTC) – nastaví se při přechodu do completed.';
