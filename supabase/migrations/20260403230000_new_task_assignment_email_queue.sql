-- =============================================================================
-- FalcoNest – Nový úkol: e-mail přes automation_message_queue (kanál email)
-- =============================================================================
-- Když je v notification_preferences zapnuté new_task_assigned_email a profil
-- má vyplněný e-mail, vloží se druhá položka fronty vedle internal_push.
-- Odbavení: Edge automation-dispatch (SMTP) – editable_payload.text + email_subject.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.enqueue_internal_push_on_new_task_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  prefs_push boolean;
  prefs_email boolean;
  worker_email text;
  service_label text;
  task_label text;
  when_ts timestamptz;
  push_title text;
  push_body text;
  email_body text;
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

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = NEW.assigned_to
      AND p.tenant_id = NEW.tenant_id
      AND p.deleted_at IS NULL
  ) THEN
    RETURN NEW;
  END IF;

  SELECT np.new_task_assigned_push, np.new_task_assigned_email
  INTO prefs_push, prefs_email
  FROM public.notification_preferences np
  WHERE np.profile_id = NEW.assigned_to;

  prefs_push := COALESCE(prefs_push, true);
  prefs_email := COALESCE(prefs_email, true);

  IF prefs_email THEN
    SELECT NULLIF(btrim(p.email), '')
    INTO worker_email
    FROM public.profiles p
    WHERE p.id = NEW.assigned_to
      AND p.tenant_id = NEW.tenant_id
      AND p.deleted_at IS NULL
    LIMIT 1;
  END IF;

  IF prefs_push IS NOT TRUE
     AND NOT (prefs_email IS TRUE AND worker_email IS NOT NULL) THEN
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

  email_body := push_body || E'\n\n' || '— FalcoNest';

  IF prefs_push IS TRUE THEN
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
  END IF;

  IF prefs_email IS TRUE AND worker_email IS NOT NULL THEN
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
      'email',
      worker_email,
      jsonb_build_object(
        'email_subject', push_title,
        'text', email_body,
        'task_id', NEW.id::text,
        'reservation_id', CASE
          WHEN NEW.reservation_id IS NOT NULL THEN NEW.reservation_id::text
          ELSE NULL
        END,
        'source', 'new_task_assigned'
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.enqueue_internal_push_on_new_task_assignment() IS
  'Po INSERT/UPDATE assigned_to: internal_push pokud new_task_assigned_push; e-mail (kanál email) pokud new_task_assigned_email a profiles.email. SECURITY DEFINER kvůli RLS na frontě.';
