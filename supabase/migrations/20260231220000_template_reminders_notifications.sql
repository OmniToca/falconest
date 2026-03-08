-- =============================================================================
-- FalcoNest – Template reminders (Time-Block push notifikace)
-- =============================================================================
-- Přidání preference template_reminders_enabled a příprava pg_cron pro Edge
-- funkci template-reminders. CRON běží pouze v 7:00, 11:00, 15:00 a 19:00
-- Madrid (Europe/Madrid) – žádné noční rušení řidičů.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Sloupec template_reminders_enabled v notification_preferences
-- -----------------------------------------------------------------------------
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS template_reminders_enabled boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.notification_preferences.template_reminders_enabled IS
  'Připomenutí odeslání šablon zpráv (48h/24h/1h před transferem).';

-- -----------------------------------------------------------------------------
-- 2. pg_cron + pg_net (extensions)
-- -----------------------------------------------------------------------------
-- Extensions jsou typicky již povoleny v Supabase. Pokud ne, odkomentuj:
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- CREATE EXTENSION IF NOT EXISTS pg_net;

-- Nastavení timezone pro cron – 7, 11, 15, 19 = Madrid čas
-- (Vyžaduje superuser; pokud selže, cron poběží v UTC – viz Supabase Dashboard.)
DO $$
BEGIN
  ALTER DATABASE postgres SET cron.timezone = 'Europe/Madrid';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'cron.timezone: nastavte ručně (Europe/Madrid) pokud je DB v UTC.';
END $$;

-- -----------------------------------------------------------------------------
-- 3. Konfigurace a funkce pro volání Edge Function
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cron_edge_config (
  key text PRIMARY KEY,
  value text NOT NULL
);

COMMENT ON TABLE public.cron_edge_config IS
  'URL a API klíč pro pg_cron volání Edge Functions. Po migraci spusťte UPDATE s vaším project ref a anon key.';

INSERT INTO public.cron_edge_config (key, value)
VALUES
  ('template_reminders_url', 'https://REPLACE_WITH_PROJECT_REF.supabase.co/functions/v1/template-reminders'),
  ('template_reminders_anon_key', 'REPLACE_WITH_ANON_KEY')
ON CONFLICT (key) DO NOTHING;

-- Funkce volaná z cron – čte URL a key z cron_edge_config
CREATE OR REPLACE FUNCTION public.invoke_template_reminders()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_url text;
  v_key text;
BEGIN
  SELECT value INTO v_url FROM public.cron_edge_config WHERE key = 'template_reminders_url' LIMIT 1;
  SELECT value INTO v_key FROM public.cron_edge_config WHERE key = 'template_reminders_anon_key' LIMIT 1;
  IF v_url IS NULL OR v_url LIKE '%REPLACE_%' OR v_key IS NULL OR v_key LIKE '%REPLACE_%' THEN
    RAISE NOTICE 'cron_edge_config: nastavte template_reminders_url a template_reminders_anon_key';
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

-- -----------------------------------------------------------------------------
-- 4. pg_cron joby – 4x denně (7:00, 11:00, 15:00, 19:00 Madrid)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'template-reminders-7am') THEN
    PERFORM cron.unschedule('template-reminders-7am');
  END IF;
  PERFORM cron.schedule('template-reminders-7am', '0 7 * * *', 'SELECT public.invoke_template_reminders()');
EXCEPTION
  WHEN undefined_table THEN RAISE NOTICE 'pg_cron neaktivní – spusťte joby přes Dashboard: Integrations → Cron.';
  WHEN OTHERS THEN RAISE;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'template-reminders-11am') THEN
    PERFORM cron.unschedule('template-reminders-11am');
  END IF;
  PERFORM cron.schedule('template-reminders-11am', '0 11 * * *', 'SELECT public.invoke_template_reminders()');
EXCEPTION
  WHEN undefined_table THEN NULL;
  WHEN OTHERS THEN RAISE;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'template-reminders-3pm') THEN
    PERFORM cron.unschedule('template-reminders-3pm');
  END IF;
  PERFORM cron.schedule('template-reminders-3pm', '0 15 * * *', 'SELECT public.invoke_template_reminders()');
EXCEPTION
  WHEN undefined_table THEN NULL;
  WHEN OTHERS THEN RAISE;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'template-reminders-7pm') THEN
    PERFORM cron.unschedule('template-reminders-7pm');
  END IF;
  PERFORM cron.schedule('template-reminders-7pm', '0 19 * * *', 'SELECT public.invoke_template_reminders()');
EXCEPTION
  WHEN undefined_table THEN NULL;
  WHEN OTHERS THEN RAISE;
END $$;

-- Po nasazení spusťte v SQL Editoru (nahraďte placeholdery):
-- UPDATE cron_edge_config SET value = 'https://VAS_PROJECT_REF.supabase.co/functions/v1/template-reminders' WHERE key = 'template_reminders_url';
-- UPDATE cron_edge_config SET value = 'VAS_ANON_KEY' WHERE key = 'template_reminders_anon_key';
