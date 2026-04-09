-- =============================================================================
-- FalcoNest – Notifikace adminům při nahlášení závady majitelem (Owner Issue)
-- =============================================================================
-- Po INSERTu úkolu typu maintenance s vyplněným created_by (majitel) vloží
-- trigger do notifications záznam pro každého admina/manažera tenantu.
-- Funkce je SECURITY DEFINER, aby obešla RLS (majitel nesmí přímo vkládat
-- notifikace pro cizí profile_id).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.notify_admins_on_owner_issue()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  admin_row RECORD;
  apartment_name_val TEXT := NULL;
  message_val TEXT;
BEGIN
  IF NEW.task_type = 'maintenance' AND NEW.created_by IS NOT NULL THEN
    -- Název bytu pro zprávu (apartment_id může být NULL u některých úkolů).
    IF NEW.apartment_id IS NOT NULL THEN
      SELECT name INTO apartment_name_val
      FROM public.apartments
      WHERE id = NEW.apartment_id AND deleted_at IS NULL
      LIMIT 1;
    END IF;

    message_val := COALESCE(TRIM(NEW.title), 'Závada');
    IF apartment_name_val IS NOT NULL AND TRIM(apartment_name_val) != '' THEN
      message_val := message_val || ' (Byt: ' || TRIM(apartment_name_val) || ')';
    END IF;

    FOR admin_row IN
      SELECT id
      FROM public.profiles
      WHERE tenant_id = NEW.tenant_id
        AND role IN ('admin', 'manager')
        AND deleted_at IS NULL
    LOOP
      INSERT INTO public.notifications (tenant_id, profile_id, title, message, type, is_read)
      VALUES (
        NEW.tenant_id,
        admin_row.id,
        'Nová závada od majitele',
        message_val,
        'owner_issue',
        false
      );
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.notify_admins_on_owner_issue() IS
  'Triggerová funkce: po INSERT úkolu typu maintenance od majitele (created_by NOT NULL) vloží notifikaci všem adminům a manažerům tenantu. SECURITY DEFINER kvůli RLS.';

-- -----------------------------------------------------------------------------
-- Trigger na tabulce tasks
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS owner_issue_notification_trigger ON public.tasks;
CREATE TRIGGER owner_issue_notification_trigger
  AFTER INSERT ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admins_on_owner_issue();
