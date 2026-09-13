-- =============================================================================
-- P2: automation-dispatch cron – volat Edge jen když je splatná pending položka
-- =============================================================================
-- PROČ (audit): minutový cron volal Edge i při prázdné frontě → konstantní baseline
-- Edge/DB nákladů. Idle check je levný SELECT … LIMIT 1 před HTTP POST.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.invoke_automation_dispatch()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_has_work boolean;
BEGIN
  -- Stejná sémantika jako Edge picker: status = pending AND scheduled_for <= now().
  SELECT EXISTS (
    SELECT 1
    FROM public.automation_message_queue q
    WHERE q.status = 'pending'
      AND q.scheduled_for <= now()
    LIMIT 1
  ) INTO v_has_work;

  IF NOT COALESCE(v_has_work, false) THEN
    RETURN 0;
  END IF;

  RETURN public._automation_invoke_http_post('automation_dispatch_url');
END;
$$;

COMMENT ON FUNCTION public.invoke_automation_dispatch() IS
  'P2: volá Edge automation-dispatch jen pokud existuje splatná pending položka ve frontě.';
