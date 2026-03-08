-- =============================================================================
-- FalcoNest – Sloupec updated_at na tasks pro Timestamp Merging (Smart Merge)
-- =============================================================================
-- PROČ: Při offline synchronizaci musí mobilní aplikace poznat, zda na serveru
-- došlo k úpravě úkolu (admin na webu) po posledním syncu pracovníka. Bez
-- updated_at bychom nemohli spolehlivě detekovat konflikt a aplikovat merge.
-- =============================================================================

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT (now() AT TIME ZONE 'utc');

COMMENT ON COLUMN public.tasks.updated_at IS 'Čas poslední změny záznamu na serveru (UTC). Pro Timestamp Merging při push pending updates z mobilu.';

-- Trigger: při každém UPDATE nastavit updated_at na now().
CREATE OR REPLACE FUNCTION public.set_tasks_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := (now() AT TIME ZONE 'utc');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tasks_updated_at_trigger ON public.tasks;
CREATE TRIGGER tasks_updated_at_trigger
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.set_tasks_updated_at();

-- Inicializace: u existujících řádků bez updated_at nastavit na now().
UPDATE public.tasks
SET updated_at = (now() AT TIME ZONE 'utc')
WHERE updated_at IS NULL;
