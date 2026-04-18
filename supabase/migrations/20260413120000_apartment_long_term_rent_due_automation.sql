-- =============================================================================
-- FalcoNest – Dlouhodobý nájem: částka, splatnost, režim (připomínka / úkol),
-- idempotence denního běhu + pg_cron volání Edge rent-monitor
-- =============================================================================
-- PROČ: Automatizace hlídá den splatnosti nájmu u bytů rental_mode = long_term.
-- Režim notification = řádky v notifications pro majitele a admin/manager tenanta;
-- režim task = úkol typu rent_collection pro zvoleného pracovníka.
-- Tabulka apartment_rent_due_runs zajišťuje nejvýše jeden „běh“ na byt + měsíc + druh.
-- =============================================================================

-- Sloupce na apartments (nullable FK na profiles pro přiřazení výběru nájmu)
ALTER TABLE public.apartments
  ADD COLUMN IF NOT EXISTS rent_amount numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rent_due_day integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS rent_collection_mode text NOT NULL DEFAULT 'notification',
  ADD COLUMN IF NOT EXISTS rent_task_assignee_id uuid;

DO $$
BEGIN
  ALTER TABLE public.apartments
    ADD CONSTRAINT apartments_rent_due_day_check
    CHECK (rent_due_day >= 1 AND rent_due_day <= 31);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.apartments
    ADD CONSTRAINT apartments_rent_collection_mode_check
    CHECK (rent_collection_mode IN ('notification', 'task'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.apartments
    ADD CONSTRAINT apartments_rent_task_assignee_id_fkey
    FOREIGN KEY (rent_task_assignee_id) REFERENCES public.profiles (id) ON DELETE SET NULL;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

COMMENT ON COLUMN public.apartments.rent_amount IS 'Měsíční nájem (dlouhodobý režim); STR typicky 0.';
COMMENT ON COLUMN public.apartments.rent_due_day IS 'Den v měsíci splatnosti nájmu (1–31), kalendář provozní zóny v Edge funkci.';
COMMENT ON COLUMN public.apartments.rent_collection_mode IS 'notification = in-app oznámení; task = úkol rent_collection pro rent_task_assignee_id.';
COMMENT ON COLUMN public.apartments.rent_task_assignee_id IS 'profiles.id pracovníka pro režim task; NULL u notification nebo nevybráno.';

-- Log idempotence: jeden záznam na (apartment, měsíc fakturace, druh běhu)
CREATE TABLE IF NOT EXISTS public.apartment_rent_due_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants (id) ON DELETE CASCADE,
  apartment_id uuid NOT NULL REFERENCES public.apartments (id) ON DELETE CASCADE,
  billing_month date NOT NULL,
  run_kind text NOT NULL CHECK (run_kind IN ('notification', 'task')),
  created_task_id uuid REFERENCES public.tasks (id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (apartment_id, billing_month, run_kind)
);

CREATE INDEX IF NOT EXISTS idx_apartment_rent_due_runs_tenant_month
  ON public.apartment_rent_due_runs (tenant_id, billing_month);

COMMENT ON TABLE public.apartment_rent_due_runs IS
  'Idempotence denního rent-monitor: jednou za billing_month a run_kind na byt. Vyplňuje Edge funkce rent-monitor (service role).';

ALTER TABLE public.apartment_rent_due_runs ENABLE ROW LEVEL SECURITY;

-- Konfigurace cronu: stejný service token jako automation (viz automation_edge_auth_token)
INSERT INTO public.cron_edge_config (key, value)
VALUES
  ('rent_monitor_url', 'https://REPLACE_WITH_PROJECT_REF.supabase.co/functions/v1/rent-monitor')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.invoke_rent_monitor()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public._automation_invoke_http_post('rent_monitor_url');
END;
$$;

COMMENT ON FUNCTION public.invoke_rent_monitor() IS
  'Denní POST na Edge rent-monitor; Authorization = automation_edge_auth_token z cron_edge_config.';

-- Jednou denně ráno (Europe/Madrid pokud je cron.timezone nastaveno v projektu)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'rent-monitor-daily') THEN
    PERFORM cron.unschedule('rent-monitor-daily');
  END IF;
  PERFORM cron.schedule(
    'rent-monitor-daily',
    '0 7 * * *',
    'SELECT public.invoke_rent_monitor()'
  );
EXCEPTION
  WHEN undefined_table THEN
    RAISE NOTICE 'pg_cron neaktivní – zaregistruj job ručně: SELECT public.invoke_rent_monitor(); 1× denně.';
  WHEN OTHERS THEN RAISE;
END $$;

-- Po nasazení (SQL Editor): UPDATE cron_edge_config SET value = 'https://<REF>.supabase.co/functions/v1/rent-monitor' WHERE key = 'rent_monitor_url';
-- Token: stejný jako u automation – automation_edge_auth_token musí být již nastaven.
