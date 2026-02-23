-- =============================================================================
-- FalcoNest – Přidání sloupce metadata (JSONB) do tabulky tasks
-- =============================================================================
-- Flexibilní data pro UI: částka k vybrání, poznámky z rezervace, číslo letu,
-- trackování času a další strukturované detaily bez nutnosti dalších migrací.
-- =============================================================================

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.tasks.metadata IS 'Flexibilní strukturovaná data pro UI (hotovost, poznámky z rezervace, číslo letu, trackování času) – JSONB, výchozí prázdný objekt.';
