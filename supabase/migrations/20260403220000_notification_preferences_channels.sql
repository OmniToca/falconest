-- =============================================================================
-- FalcoNest – notification_preferences: matice kanálů (web / push / e-mail)
-- =============================================================================
-- Nahrazuje jednotlivé booleany (*_enabled) trojicí sloupců na typ události.
-- Migrace: stará hodnota false → všechny tři kanály false; true → všechny true.
-- =============================================================================

ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS daily_summary_web boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS daily_summary_push boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS daily_summary_email boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS upcoming_task_web boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS upcoming_task_push boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS upcoming_task_email boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS new_task_assigned_web boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS new_task_assigned_push boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS new_task_assigned_email boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS template_reminders_web boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS template_reminders_push boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS template_reminders_email boolean NOT NULL DEFAULT true;

UPDATE public.notification_preferences
SET
  daily_summary_web = daily_summary_enabled,
  daily_summary_push = daily_summary_enabled,
  daily_summary_email = daily_summary_enabled,
  upcoming_task_web = upcoming_task_enabled,
  upcoming_task_push = upcoming_task_enabled,
  upcoming_task_email = upcoming_task_enabled,
  new_task_assigned_web = new_task_assigned_enabled,
  new_task_assigned_push = new_task_assigned_enabled,
  new_task_assigned_email = new_task_assigned_enabled,
  template_reminders_web = template_reminders_enabled,
  template_reminders_push = template_reminders_enabled,
  template_reminders_email = template_reminders_enabled;

ALTER TABLE public.notification_preferences
  DROP COLUMN IF EXISTS daily_summary_enabled,
  DROP COLUMN IF EXISTS upcoming_task_enabled,
  DROP COLUMN IF EXISTS new_task_assigned_enabled,
  DROP COLUMN IF EXISTS template_reminders_enabled;

COMMENT ON TABLE public.notification_preferences IS
  'Preference oznámení na profil – pro každý typ události lze zvlášť zapnout Web (aplikace), Push (mobil), E-mail.';

COMMENT ON COLUMN public.notification_preferences.daily_summary_web IS 'Ranní souhrn – oznámení v aplikaci (zvoneček).';
COMMENT ON COLUMN public.notification_preferences.daily_summary_push IS 'Ranní souhrn – mobilní push (FCM).';
COMMENT ON COLUMN public.notification_preferences.daily_summary_email IS 'Ranní souhrn – e-mail.';

COMMENT ON COLUMN public.notification_preferences.upcoming_task_web IS 'Blížící se termín – web.';
COMMENT ON COLUMN public.notification_preferences.upcoming_task_push IS 'Blížící se termín – push.';
COMMENT ON COLUMN public.notification_preferences.upcoming_task_email IS 'Blížící se termín – e-mail.';

COMMENT ON COLUMN public.notification_preferences.new_task_assigned_web IS 'Nový úkol – web.';
COMMENT ON COLUMN public.notification_preferences.new_task_assigned_push IS 'Nový úkol – push (fronta internal_push).';
COMMENT ON COLUMN public.notification_preferences.new_task_assigned_email IS 'Nový úkol – e-mail.';

COMMENT ON COLUMN public.notification_preferences.template_reminders_web IS 'Připomenutí šablon – web.';
COMMENT ON COLUMN public.notification_preferences.template_reminders_push IS 'Připomenutí šablon – push (FCM).';
COMMENT ON COLUMN public.notification_preferences.template_reminders_email IS 'Připomenutí šablon – e-mail.';

-- Trigger „nový úkol“: fronta internal_push jen při zapnutém push kanálu
CREATE OR REPLACE FUNCTION public.enqueue_internal_push_on_new_task_assignment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  prefs_push boolean;
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
    (SELECT np.new_task_assigned_push
     FROM public.notification_preferences np
     WHERE np.profile_id = NEW.assigned_to),
    true
  ) INTO prefs_push;

  IF prefs_push IS NOT TRUE THEN
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
  'Po INSERT/UPDATE assigned_to vloží položku internal_push, pokud má assignee zapnuté new_task_assigned_push. SECURITY DEFINER kvůli RLS na frontě.';
