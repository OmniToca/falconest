-- =============================================================================
-- FalcoNest – Push (FCM) při přiřazení úkolu pracovníkovi
-- =============================================================================
-- PROČ: Stejný stack jako ostatní internal_push – řádek ve frontě
-- [automation_message_queue], odbavení Edge [automation-dispatch] (FCM v1, user_devices).
-- Trigger je SECURITY DEFINER (RLS by jinak blokovala INSERT s rule_id NULL u entity task).
-- Respektuje [notification_preferences.new_task_assigned_enabled]; chybějící řádek = výchozí zapnuto.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.enqueue_internal_push_on_new_task_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  prefs_enabled boolean;
  service_label text;
  task_label text;
  when_ts timestamptz;
  push_title text;
  push_body text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.assigned_to IS NULL OR NEW.deleted_at IS NOT NULL THEN
      RETURN NEW;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.assigned_to IS NULL OR NEW.deleted_at IS NOT NULL THEN
      RETURN NEW;
    END IF;
    IF OLD.assigned_to IS NOT DISTINCT FROM NEW.assigned_to THEN
      RETURN NEW;
    END IF;
  ELSE
    RETURN NEW;
  END IF;

  -- Jen aktivní profil v rámci tenanta (assigned_to = profiles.id, ne invitation apod.)
  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = NEW.assigned_to
      AND p.tenant_id = NEW.tenant_id
      AND p.deleted_at IS NULL
  ) THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(
    (SELECT np.new_task_assigned_enabled
     FROM public.notification_preferences np
     WHERE np.profile_id = NEW.assigned_to),
    true
  ) INTO prefs_enabled;

  IF prefs_enabled IS NOT TRUE THEN
    RETURN NEW;
  END IF;

  SELECT ts.name
  INTO service_label
  FROM public.tenant_services ts
  WHERE ts.id = NEW.service_id
    AND ts.tenant_id = NEW.tenant_id
    AND ts.deleted_at IS NULL
  LIMIT 1;

  task_label := COALESCE(
    NULLIF(btrim(service_label), ''),
    NULLIF(btrim(NEW.custom_title), ''),
    NULLIF(btrim(NEW.title), ''),
    NULLIF(btrim(NEW.task_type), ''),
    'Úkol'
  );

  push_title := 'Nový úkol: ' || task_label;

  when_ts := COALESCE(NEW.scheduled_start, NEW.due_date);
  IF when_ts IS NOT NULL THEN
    push_body := 'Byl vám přidělen nový úkol na '
      || to_char(timezone('Europe/Prague', when_ts), 'DD.MM.YYYY HH24:MI')
      || '.';
  ELSE
    push_body := 'Byl vám přidělen nový úkol.';
  END IF;

  INSERT INTO public.automation_message_queue (
    tenant_id,
    rule_id,
    entity_id,
    entity_type,
    scheduled_for,
    channel,
    recipient_contact,
    editable_payload
  ) VALUES (
    NEW.tenant_id,
    NULL,
    NEW.id,
    'task',
    now(),
    'internal_push',
    NEW.assigned_to::text,
    jsonb_build_object(
      'internal_push_kind', 'new_task_assigned',
      'push_title', push_title,
      'push_body', push_body,
      'task_id', NEW.id::text,
      'reservation_id', CASE
        WHEN NEW.reservation_id IS NOT NULL THEN NEW.reservation_id::text
        ELSE NULL
      END
    )
  );

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.enqueue_internal_push_on_new_task_assignment() IS
  'Po INSERT/UPDATE assigned_to vloží položku internal_push do automation_message_queue, pokud má assignee zapnuté new_task_assigned_enabled. SECURITY DEFINER kvůli RLS na frontě.';

DROP TRIGGER IF EXISTS tasks_enqueue_new_assignment_push ON public.tasks;
CREATE TRIGGER tasks_enqueue_new_assignment_push
  AFTER INSERT OR UPDATE OF assigned_to ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.enqueue_internal_push_on_new_task_assignment();
