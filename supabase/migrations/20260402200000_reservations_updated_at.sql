-- =============================================================================
-- FalcoNest – Sloupec updated_at na reservations pro Timestamp Merging (Smart Merge)
-- =============================================================================
-- PROČ: Worker v terénu mění typicky jen status rezervace; admin mezitím může upravit
-- termíny, poznámky apod. Mobil při pushi musí detekovat novější serverovou verzi
-- (stejný model jako u tabulky tasks) a po odeslání statusu zarovnat lokální Drift
-- se snapshotem ze serveru, aby UI neukazovalo zastaralá data.
-- =============================================================================

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT (now() AT TIME ZONE 'utc');

COMMENT ON COLUMN public.reservations.updated_at IS 'Čas poslední změny záznamu na serveru (UTC). Pro Timestamp Merging při push pending reservation updates z mobilu.';

CREATE OR REPLACE FUNCTION public.set_reservations_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := (now() AT TIME ZONE 'utc');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS reservations_updated_at_trigger ON public.reservations;
CREATE TRIGGER reservations_updated_at_trigger
  BEFORE UPDATE ON public.reservations
  FOR EACH ROW
  EXECUTE FUNCTION public.set_reservations_updated_at();

UPDATE public.reservations
SET updated_at = (now() AT TIME ZONE 'utc')
WHERE updated_at IS NULL;
