-- =============================================================================
-- FalcoNest – Automatizace: pg_cron + pg_net + trigger na reservations
-- =============================================================================
-- PROČ: Edge funkce `automation-enqueue` (plánování do fronty) a
-- `automation-dispatch` (odeslání) v aplikaci nikdo nevolá. Tato migrace:
-- 1) povolí rozšíření pro plánování a HTTP z DB,
-- 2) přidá do `cron_edge_config` placeholdery pro URL a tajný klíč (bez Gitu),
-- 3) zaregistruje cron joby (enqueue každých 15 min, dispatch každou minutu),
-- 4) po INSERT/UPDATE na `reservations` jednou za příkaz zavolá enqueue (okamžitá pravidla).
--
-- PO NASAZENÍ (Supabase SQL Editor, hodnoty neukládej do repozitáře):
--   UPDATE public.cron_edge_config SET value = 'https://<PROJECT_REF>.supabase.co/functions/v1/automation-enqueue'
--     WHERE key = 'automation_enqueue_url';
--   UPDATE public.cron_edge_config SET value = 'https://<PROJECT_REF>.supabase.co/functions/v1/automation-dispatch'
--     WHERE key = 'automation_dispatch_url';
--   UPDATE public.cron_edge_config SET value = '<SERVICE_ROLE_JWT>' WHERE key = 'automation_edge_auth_token';
--
-- Alternativa k ručnímu UPDATE: uložit stejný secret do Supabase Vault a upravit funkce
-- níže na čtení z `vault.decrypted_secrets` (viz komentář u [invoke_automation_*]).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Rozšíření pg_cron a pg_net
-- -----------------------------------------------------------------------------
-- PROČ: Na hosted Supabase jsou často již povolená; lokálně může CREATE selhat bez práv.
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron: nelze vytvořit (práva nebo již existuje): %', SQLERRM;
END $$;

DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_net: nelze vytvořit (práva nebo již existuje): %', SQLERRM;
END $$;

-- Kompatibilita: některé projekty instalují pg_net do schématu public
-- (funkce pak voláme jako net.http_post, ne extensions.net.http_post).

-- -----------------------------------------------------------------------------
-- 2) Konfigurační řádky pro Automation Edge (stejná tabulka jako template-reminders)
-- -----------------------------------------------------------------------------
-- PROČ: Tajný klíč nesmí být v Gitu. Placeholdery se nahradí v Dashboard / SQL Editoru.
INSERT INTO public.cron_edge_config (key, value)
VALUES
  ('automation_enqueue_url', 'https://REPLACE_WITH_PROJECT_REF.supabase.co/functions/v1/automation-enqueue'),
  ('automation_dispatch_url', 'https://REPLACE_WITH_PROJECT_REF.supabase.co/functions/v1/automation-dispatch'),
  ('automation_edge_auth_token', 'REPLACE_WITH_SERVICE_ROLE_JWT')
ON CONFLICT (key) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 3) Pomocná funkce: bezpečné načtení tokenu a volání net.http_post
-- -----------------------------------------------------------------------------
-- PROČ: Jedno místo pro hlavičky Supabase Functions (Authorization + apikey – očekává gateway).
CREATE OR REPLACE FUNCTION public._automation_invoke_http_post(p_url_key text)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url text;
  v_token text;
BEGIN
  SELECT c.value INTO v_url FROM public.cron_edge_config c WHERE c.key = p_url_key LIMIT 1;
  SELECT c.value INTO v_token FROM public.cron_edge_config c WHERE c.key = 'automation_edge_auth_token' LIMIT 1;

  IF v_url IS NULL OR v_url LIKE '%REPLACE_%' OR v_token IS NULL OR v_token LIKE '%REPLACE_%' THEN
    RAISE NOTICE 'cron_edge_config: nastavte % a automation_edge_auth_token (viz migrace hlavička).', p_url_key;
    RETURN 0;
  END IF;

  -- Volitelně: místo cron_edge_config načti token z Vaultu (po CREATE SECRET v Dashboard):
  -- v_token := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role' LIMIT 1);

  RETURN net.http_post(
    url := v_url,
    body := '{}'::jsonb,
    params := '{}'::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_token,
      'apikey', v_token
    ),
    timeout_milliseconds := 120000
  );
END;
$$;

COMMENT ON FUNCTION public._automation_invoke_http_post(text) IS
  'Interní POST na Edge Function; token jen z cron_edge_config (ne z Gitu).';

-- -----------------------------------------------------------------------------
-- 4) Veřejné funkce pro cron a trigger
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.invoke_automation_enqueue()
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public._automation_invoke_http_post('automation_enqueue_url');
$$;

CREATE OR REPLACE FUNCTION public.invoke_automation_dispatch()
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public._automation_invoke_http_post('automation_dispatch_url');
$$;

COMMENT ON FUNCTION public.invoke_automation_enqueue() IS
  'Volá Edge automation-enqueue (plánování fronty). Používá pg_cron a trigger na reservations.';

COMMENT ON FUNCTION public.invoke_automation_dispatch() IS
  'Volá Edge automation-dispatch (odbavení fronty).';

-- -----------------------------------------------------------------------------
-- 5) pg_cron – pravidelné běhy
-- -----------------------------------------------------------------------------
-- PROČ: enqueue projde časová pravidla (offsety vůči check-inu apod.); dispatch čekárnu často odbaví.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'automation-enqueue-15m') THEN
    PERFORM cron.unschedule('automation-enqueue-15m');
  END IF;
  PERFORM cron.schedule(
    'automation-enqueue-15m',
    '*/15 * * * *',
    'SELECT public.invoke_automation_enqueue();'
  );
EXCEPTION
  WHEN undefined_table THEN
    RAISE NOTICE 'pg_cron neaktivní – zaregistruj job ručně (Integrations → Cron): SELECT public.invoke_automation_enqueue(); každých 15 min.';
  WHEN OTHERS THEN
    RAISE NOTICE 'automation-enqueue cron: %', SQLERRM;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'automation-dispatch-1m') THEN
    PERFORM cron.unschedule('automation-dispatch-1m');
  END IF;
  PERFORM cron.schedule(
    'automation-dispatch-1m',
    '* * * * *',
    'SELECT public.invoke_automation_dispatch();'
  );
EXCEPTION
  WHEN undefined_table THEN
    RAISE NOTICE 'pg_cron neaktivní – zaregistruj job ručně: SELECT public.invoke_automation_dispatch(); každou minutu.';
  WHEN OTHERS THEN
    RAISE NOTICE 'automation-dispatch cron: %', SQLERRM;
END $$;

-- -----------------------------------------------------------------------------
-- 6) Trigger na reservations – jeden POST na příkaz (ne na každý řádek)
-- -----------------------------------------------------------------------------
-- PROČ: Po hromadném UPDATE nechceme N HTTP požadavků; FOR EACH STATEMENT stačí,
-- protože enqueue stejně projde všechny splatné entity v jednom běhu.
CREATE OR REPLACE FUNCTION public.notify_automation_enqueue_on_reservations_stmt()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.invoke_automation_enqueue();
  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.notify_automation_enqueue_on_reservations_stmt() IS
  'Po změně rezervací naplánuje (asynchronně po COMMIT) jeden běh automation-enqueue přes pg_net.';

DROP TRIGGER IF EXISTS trg_reservations_automation_enqueue_stmt ON public.reservations;

CREATE TRIGGER trg_reservations_automation_enqueue_stmt
AFTER INSERT OR UPDATE ON public.reservations
FOR EACH STATEMENT
EXECUTE PROCEDURE public.notify_automation_enqueue_on_reservations_stmt();

COMMENT ON TRIGGER trg_reservations_automation_enqueue_stmt ON public.reservations IS
  'Okamžitá pravidla (např. nová rezervace): jeden enqueue běh po INSERT/UPDATE dávce.';
