-- =============================================================================
-- FalcoNest – pg_cron: upcoming-task-reminder (každých 15 minut)
-- =============================================================================
-- Po nasazení: UPDATE public.cron_edge_config SET value = 'https://<REF>.supabase.co/functions/v1/upcoming-task-reminder'
--   WHERE key = 'upcoming_task_reminder_url';
--   a stejně upcoming_task_reminder_anon_key (anon public API key).
-- =============================================================================

INSERT INTO public.cron_edge_config (key, value)
VALUES
  ('upcoming_task_reminder_url', 'https://REPLACE_WITH_PROJECT_REF.supabase.co/functions/v1/upcoming-task-reminder'),
  ('upcoming_task_reminder_anon_key', 'REPLACE_WITH_ANON_KEY')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.invoke_upcoming_task_reminder()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url text;
  v_key text;
BEGIN
  SELECT value INTO v_url FROM public.cron_edge_config WHERE key = 'upcoming_task_reminder_url' LIMIT 1;
  SELECT value INTO v_key FROM public.cron_edge_config WHERE key = 'upcoming_task_reminder_anon_key' LIMIT 1;
  IF v_url IS NULL OR v_url LIKE '%REPLACE_%' OR v_key IS NULL OR v_key LIKE '%REPLACE_%' THEN
    RAISE NOTICE 'cron_edge_config: nastavte upcoming_task_reminder_url a upcoming_task_reminder_anon_key';
    RETURN 0;
  END IF;
  RETURN net.http_get(
    v_url,
    '{}'::jsonb,
    jsonb_build_object('Authorization', 'Bearer ' || v_key),
    10000
  );
END;
$$;

COMMENT ON FUNCTION public.invoke_upcoming_task_reminder() IS
  'POST-free GET volání Edge upcoming-task-reminder (anon JWT); idempotence v upcoming_task_reminder_log.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'upcoming-task-reminder-15m') THEN
    PERFORM cron.unschedule('upcoming-task-reminder-15m');
  END IF;
  PERFORM cron.schedule(
    'upcoming-task-reminder-15m',
    '*/15 * * * *',
    'SELECT public.invoke_upcoming_task_reminder()'
  );
EXCEPTION
  WHEN undefined_table THEN
    RAISE NOTICE 'pg_cron neaktivní – zaregistruj job ručně: SELECT public.invoke_upcoming_task_reminder(); každých 15 min.';
  WHEN OTHERS THEN RAISE;
END $$;
