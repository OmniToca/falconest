-- =============================================================================
-- P0: Cron Edge joby – Authorization = service role (ne anon key)
-- =============================================================================
-- PROČ: Edge upcoming-task-reminder / template-reminders / daily-task-summary
-- nyní vyžadují Bearer == SUPABASE_SERVICE_ROLE_KEY.
-- Použijeme existující _automation_invoke_http_post(url_key), které čte
-- automation_edge_auth_token (stejně jako rent-monitor / automation).
-- =============================================================================

-- upcoming-task-reminder: POST se service tokenem (místo GET + anon)
CREATE OR REPLACE FUNCTION public.invoke_upcoming_task_reminder()
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public._automation_invoke_http_post('upcoming_task_reminder_url');
$$;

COMMENT ON FUNCTION public.invoke_upcoming_task_reminder() IS
  'P0: volá Edge upcoming-task-reminder přes _automation_invoke_http_post (service role Bearer).';

-- template-reminders
CREATE OR REPLACE FUNCTION public.invoke_template_reminders()
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public._automation_invoke_http_post('template_reminders_url');
$$;

COMMENT ON FUNCTION public.invoke_template_reminders() IS
  'P0: volá Edge template-reminders přes _automation_invoke_http_post (service role Bearer).';

-- daily-task-summary (pokud URL klíč / funkce existují)
INSERT INTO public.cron_edge_config (key, value)
VALUES
  ('daily_task_summary_url', 'https://REPLACE_WITH_PROJECT_REF.supabase.co/functions/v1/daily-task-summary')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.invoke_daily_task_summary()
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public._automation_invoke_http_post('daily_task_summary_url');
$$;

COMMENT ON FUNCTION public.invoke_daily_task_summary() IS
  'P0: volá Edge daily-task-summary přes _automation_invoke_http_post (service role Bearer).';
