-- =============================================================================
-- FalcoNest – Majitel: životní cyklus úkolu + výběr hotovosti → fronta + zvoneček
-- =============================================================================
-- PROČ: UI ukládá kanály v notification_preferences (owner_task_* / owner_cash_*),
-- ale chyběl DB spojovník. Tato migrace při změně stavu úkolu (in_progress / completed)
-- a při INSERT COLLECTED_FROM_GUEST vyhledá majitele přes apartment_owners a:
--   • při zapnutém push nebo e-mailu vloží řádky do automation_message_queue
--     (kanály internal_push + email, rule_id NULL — stejný model jako u new_task_assigned);
--   • při zapnutém web (in-app zvoneček) vloží řádek do notifications.
-- SECURITY DEFINER: obchází RLS na frontě a notifications při systémové události.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Jádro: jedna funkce pro všechny tři typy událostí (DRY, jedna smyčka majitelů).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enqueue_owner_lifecycle_notifications(
  p_tenant_id uuid,
  p_apartment_id uuid,
  p_event text,
  p_task_id uuid DEFAULT NULL,
  p_reservation_id uuid DEFAULT NULL,
  p_cash_transaction_id uuid DEFAULT NULL,
  p_cash_amount numeric DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r_owner record;
  v_apt_name text;
  v_task_label text;
  v_title text;
  v_body text;
  v_push_kind text;
  v_notif_type text;
  prefs_web boolean;
  prefs_push boolean;
  prefs_email boolean;
  v_owner_email text;
  v_entity_id uuid;
  v_entity_type text;
BEGIN
  IF p_event NOT IN ('task_started', 'task_completed', 'cash_collected') THEN
    RETURN;
  END IF;

  IF p_apartment_id IS NULL OR p_tenant_id IS NULL THEN
    RETURN;
  END IF;

  SELECT NULLIF(btrim(a.name), '')
  INTO v_apt_name
  FROM public.apartments a
  WHERE a.id = p_apartment_id
    AND a.tenant_id = p_tenant_id
    AND a.deleted_at IS NULL
  LIMIT 1;

  v_apt_name := COALESCE(v_apt_name, 'Apartmán');

  -- Popisek úkolu (stejná heuristika jako u fronty „nový úkol“).
  IF p_task_id IS NOT NULL AND p_event IN ('task_started', 'task_completed') THEN
    SELECT COALESCE(
      NULLIF(btrim(ts.name), ''),
      NULLIF(btrim(t.custom_title), ''),
      NULLIF(btrim(t.title), ''),
      NULLIF(btrim(t.task_type), ''),
      'Úkol'
    )
    INTO v_task_label
    FROM public.tasks t
    LEFT JOIN public.tenant_services ts
      ON ts.id = t.service_id
     AND ts.tenant_id = t.tenant_id
     AND ts.deleted_at IS NULL
    WHERE t.id = p_task_id
      AND t.tenant_id = p_tenant_id
    LIMIT 1;
  END IF;

  v_task_label := COALESCE(v_task_label, 'Úkol');

  IF p_event = 'task_started' THEN
    v_push_kind := 'owner_task_started';
    v_notif_type := 'owner_task_started';
    v_title := 'Zahájena práce u vašeho apartmánu';
    v_body := format('%s: byla zahájena práce na úkolu „%s“.', v_apt_name, v_task_label);
    v_entity_id := p_task_id;
    v_entity_type := 'task';
  ELSIF p_event = 'task_completed' THEN
    v_push_kind := 'owner_task_completed';
    v_notif_type := 'owner_task_completed';
    v_title := 'Dokončena práce u vašeho apartmánu';
    v_body := format('%s: byl dokončen úkol „%s“.', v_apt_name, v_task_label);
    v_entity_id := p_task_id;
    v_entity_type := 'task';
  ELSE
    v_push_kind := 'owner_cash_collected';
    v_notif_type := 'owner_cash_collected';
    v_title := 'Vybrána hotovost od hosta';
    v_body := format(
      '%s: pracovník zaznamenal výběr hotovosti v částce %s.',
      v_apt_name,
      trim(to_char(round(COALESCE(p_cash_amount, 0), 2), 'FM9999999999990.09'))
    );
    -- Fronta: u hotovosti použijeme úkol jako entitu, pokud existuje (RLS + konzistence),
    -- jinak adhoc řádek vázaný na ID transakce (entity_type z migrace adhoc).
    IF p_task_id IS NOT NULL THEN
      v_entity_id := p_task_id;
      v_entity_type := 'task';
    ELSE
      v_entity_id := p_cash_transaction_id;
      v_entity_type := 'adhoc';
    END IF;
    IF v_entity_id IS NULL THEN
      RETURN;
    END IF;
  END IF;

  IF p_event IN ('task_started', 'task_completed') AND v_entity_id IS NULL THEN
    RETURN;
  END IF;

  FOR r_owner IN
    SELECT ao.owner_id
    FROM public.apartment_owners ao
    INNER JOIN public.apartments a
      ON a.id = ao.apartment_id
     AND a.tenant_id = p_tenant_id
    WHERE ao.apartment_id = p_apartment_id
      AND ao.deleted_at IS NULL
      AND a.deleted_at IS NULL
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = r_owner.owner_id
        AND p.tenant_id = p_tenant_id
        AND p.deleted_at IS NULL
    ) THEN
      CONTINUE;
    END IF;

    -- Skalární poddotazy: bez řádku v notification_preferences vrátí NULL → výchozí zapnuto (opt-out matice).
    prefs_web := COALESCE(
      (
        SELECT CASE p_event
          WHEN 'task_started' THEN np.owner_task_started_web
          WHEN 'task_completed' THEN np.owner_task_completed_web
          ELSE np.owner_cash_collected_web
        END
        FROM public.notification_preferences np
        WHERE np.profile_id = r_owner.owner_id
      ),
      true
    );
    prefs_push := COALESCE(
      (
        SELECT CASE p_event
          WHEN 'task_started' THEN np.owner_task_started_push
          WHEN 'task_completed' THEN np.owner_task_completed_push
          ELSE np.owner_cash_collected_push
        END
        FROM public.notification_preferences np
        WHERE np.profile_id = r_owner.owner_id
      ),
      true
    );
    prefs_email := COALESCE(
      (
        SELECT CASE p_event
          WHEN 'task_started' THEN np.owner_task_started_email
          WHEN 'task_completed' THEN np.owner_task_completed_email
          ELSE np.owner_cash_collected_email
        END
        FROM public.notification_preferences np
        WHERE np.profile_id = r_owner.owner_id
      ),
      true
    );

    v_owner_email := NULL;
    IF prefs_email THEN
      SELECT NULLIF(btrim(p.email), '')
      INTO v_owner_email
      FROM public.profiles p
      WHERE p.id = r_owner.owner_id
        AND p.tenant_id = p_tenant_id
        AND p.deleted_at IS NULL
      LIMIT 1;
    END IF;

    -- -------------------------------------------------------------------------
    -- automation_message_queue / internal_push
    -- Sloupce: tenant_id, rule_id (NULL = systémová fronta), entity_id, entity_type,
    -- scheduled_for (now UTC), channel internal_push, recipient_contact = UUID majitele
    -- (stejné jako u worker new_task_assigned), editable_payload = titulek, tělo, kind,
    -- task_id / apartment_id / reservation_id pro Edge automation-dispatch (FCM data).
    -- -------------------------------------------------------------------------
    IF prefs_push THEN
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
        p_tenant_id,
        NULL,
        v_entity_id,
        v_entity_type,
        now(),
        'internal_push',
        r_owner.owner_id::text,
        jsonb_build_object(
          'internal_push_kind', v_push_kind,
          'push_title', v_title,
          'push_body', v_body,
          'task_id', CASE WHEN p_task_id IS NOT NULL THEN p_task_id::text ELSE NULL END,
          'apartment_id', p_apartment_id::text,
          'reservation_id', CASE WHEN p_reservation_id IS NOT NULL THEN p_reservation_id::text ELSE NULL END,
          'cash_transaction_id', CASE WHEN p_cash_transaction_id IS NOT NULL THEN p_cash_transaction_id::text ELSE NULL END
        )
      );
    END IF;

    -- -------------------------------------------------------------------------
    -- automation_message_queue / email
    -- recipient_contact = e-mail majitele; editable_payload musí obsahovat text + email_subject.
    -- Pozn.: task_id záměrně neposíláme — Edge šablona by jinak doplnila odkaz na /worker/task.
    -- -------------------------------------------------------------------------
    IF prefs_email AND v_owner_email IS NOT NULL THEN
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
        p_tenant_id,
        NULL,
        v_entity_id,
        v_entity_type,
        now(),
        'email',
        v_owner_email,
        jsonb_build_object(
          'email_subject', v_title,
          'text', v_body || E'\n\n— FalcoNest',
          'source', v_push_kind,
          'apartment_id', p_apartment_id::text
        )
      );
    END IF;

    -- -------------------------------------------------------------------------
    -- notifications (in-app zvoneček) — owner_*_web sloupce v notification_preferences.
    -- metadata: proklik v aplikaci (task_id, apartment_id, …).
    -- -------------------------------------------------------------------------
    IF prefs_web THEN
      INSERT INTO public.notifications (
        tenant_id,
        profile_id,
        title,
        message,
        type,
        is_read,
        metadata
      ) VALUES (
        p_tenant_id,
        r_owner.owner_id,
        v_title,
        v_body,
        v_notif_type,
        false,
        jsonb_build_object(
          'task_id', CASE WHEN p_task_id IS NOT NULL THEN p_task_id::text ELSE NULL END,
          'apartment_id', p_apartment_id::text,
          'reservation_id', CASE WHEN p_reservation_id IS NOT NULL THEN p_reservation_id::text ELSE NULL END,
          'cash_transaction_id', CASE WHEN p_cash_transaction_id IS NOT NULL THEN p_cash_transaction_id::text ELSE NULL END,
          'entity', 'owner_lifecycle'
        )
      );
    END IF;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION public.enqueue_owner_lifecycle_notifications(
  uuid, uuid, text, uuid, uuid, uuid, numeric
) IS
  'Systémově zařadí majiteli oznámení (fronta internal_push/email + tabulka notifications) podle notification_preferences. Voláno jen z triggerů; SECURITY DEFINER kvůli RLS.';

REVOKE ALL ON FUNCTION public.enqueue_owner_lifecycle_notifications(
  uuid, uuid, text, uuid, uuid, uuid, numeric
) FROM PUBLIC;

-- -----------------------------------------------------------------------------
-- Trigger: změna statusu úkolu → in_progress / completed
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_tasks_owner_lifecycle_notify()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event text;
BEGIN
  IF NEW.deleted_at IS NOT NULL OR NEW.apartment_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  v_event := NULL;
  IF NEW.status = 'in_progress' AND OLD.status IS DISTINCT FROM 'in_progress' THEN
    v_event := 'task_started';
  ELSIF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed' THEN
    v_event := 'task_completed';
  END IF;

  IF v_event IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM public.enqueue_owner_lifecycle_notifications(
    NEW.tenant_id,
    NEW.apartment_id,
    v_event,
    NEW.id,
    NEW.reservation_id,
    NULL,
    NULL
  );

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_tasks_owner_lifecycle_notify() IS
  'Po přechodu úkolu na in_progress nebo completed notifikuje majitele bytu dle notification_preferences.';

DROP TRIGGER IF EXISTS tasks_owner_lifecycle_notify ON public.tasks;
CREATE TRIGGER tasks_owner_lifecycle_notify
  AFTER UPDATE OF status ON public.tasks
  FOR EACH ROW
  WHEN (
    OLD.status IS DISTINCT FROM NEW.status
    AND NEW.deleted_at IS NULL
    AND NEW.apartment_id IS NOT NULL
  )
  EXECUTE FUNCTION public.trg_tasks_owner_lifecycle_notify();

-- -----------------------------------------------------------------------------
-- Trigger: výběr hotovosti od hosta (účetní kniha zaměstnance)
-- PROČ: COLLECTED_FROM_GUEST je přesný okamžik „host zaplatil“, ne až settlement majiteli.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_employee_cash_owner_notify_on_collect()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_apartment uuid;
  v_task uuid;
  v_reservation uuid;
  v_from_task_apartment uuid;
BEGIN
  IF NEW.transaction_type IS DISTINCT FROM 'COLLECTED_FROM_GUEST' THEN
    RETURN NEW;
  END IF;

  IF NEW.amount IS NULL OR NEW.amount <= 0 THEN
    RETURN NEW;
  END IF;

  v_apartment := NEW.apartment_id;
  v_task := NEW.task_id;
  v_reservation := NULL;
  v_from_task_apartment := NULL;

  IF v_task IS NOT NULL THEN
    SELECT t.apartment_id, t.reservation_id
    INTO v_from_task_apartment, v_reservation
    FROM public.tasks t
    WHERE t.id = v_task
      AND t.tenant_id = NEW.tenant_id
    LIMIT 1;
    v_apartment := COALESCE(v_apartment, v_from_task_apartment);
  END IF;

  IF v_apartment IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM public.enqueue_owner_lifecycle_notifications(
    NEW.tenant_id,
    v_apartment,
    'cash_collected',
    v_task,
    v_reservation,
    NEW.id,
    NEW.amount
  );

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_employee_cash_owner_notify_on_collect() IS
  'Po INSERT COLLECTED_FROM_GUEST notifikuje majitele bytu (apartment z řádku nebo z úkolu).';

DROP TRIGGER IF EXISTS employee_cash_transactions_owner_notify_on_collect ON public.employee_cash_transactions;
CREATE TRIGGER employee_cash_transactions_owner_notify_on_collect
  AFTER INSERT ON public.employee_cash_transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_employee_cash_owner_notify_on_collect();

REVOKE ALL ON FUNCTION public.trg_tasks_owner_lifecycle_notify() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.trg_employee_cash_owner_notify_on_collect() FROM PUBLIC;
