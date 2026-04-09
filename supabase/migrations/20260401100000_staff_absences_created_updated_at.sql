-- =============================================================================
-- FalcoNest – staff_absences: časová razítka pro mobilní sync
-- =============================================================================
-- PROČ: WorkerSyncService při SELECT požaduje sloupce created_at a updated_at.
-- Pokud v PostgreSQL chybí, PostgREST vrátí chybu a synchronizace nepřítomností selže.
-- ADD COLUMN IF NOT EXISTS je idempotentní – bezpečné na již částečně upravených DB.
-- =============================================================================

ALTER TABLE public.staff_absences
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.staff_absences
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

COMMENT ON COLUMN public.staff_absences.created_at IS
  'Čas vytvoření záznamu; výchozí now() pro legacy řádky při první migraci.';

COMMENT ON COLUMN public.staff_absences.updated_at IS
  'Čas poslední změny; výchozí now() pro legacy řádky při první migraci.';
