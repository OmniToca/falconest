-- =============================================================================
-- FalcoNest – Automatická změna stavu rezervace při dokončení úkolu Check-in / Check-out
-- =============================================================================
-- PROČ: Ať úkol dokončí admin na webu nebo pracovník offline na mobilu, databáze
-- vždy nastaví rezervaci na checked_in / checked_out. Jedno místo logiky, nezávislé na klientovi.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.auto_update_reservation_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  task_type_norm text;
BEGIN
  -- Pouze při přechodu na stav completed a s vazbou na rezervaci
  IF OLD.status IS DISTINCT FROM 'completed' AND NEW.status = 'completed'
     AND NEW.reservation_id IS NOT NULL THEN

    task_type_norm := LOWER(TRIM(COALESCE(NEW.task_type, '')));

    IF task_type_norm = 'check_in' THEN
      UPDATE public.reservations
      SET status = 'checked_in'
      WHERE id = NEW.reservation_id;
    ELSIF task_type_norm IN ('check_out', 'checkout') THEN
      UPDATE public.reservations
      SET status = 'checked_out'
      WHERE id = NEW.reservation_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.auto_update_reservation_status() IS
  'Triggerová funkce: při dokončení úkolu (status=completed) typu Check-in/Check-out nastaví stav nadřazené rezervace na checked_in/checked_out.';

DROP TRIGGER IF EXISTS trigger_auto_update_reservation_status ON public.tasks;
CREATE TRIGGER trigger_auto_update_reservation_status
  AFTER UPDATE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_update_reservation_status();
