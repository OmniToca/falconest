-- =============================================================================
-- FalcoNest Automations (ČÁST 1.1)
-- Aditivní základ: pravidla, fronta zpráv, audit log, měsíční agregace usage.
--
-- Multitenant: Každá nová tabulka má `tenant_id` a RLS je striktně omezeno
-- na tenant aktuálně přihlášeného uživatele (public.my_tenant_id()).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) ENUM typy
-- -----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'automation_channel') THEN
    CREATE TYPE public.automation_channel AS ENUM ('email', 'sms', 'whatsapp');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'automation_queue_status') THEN
    CREATE TYPE public.automation_queue_status AS ENUM ('pending', 'processing', 'sent', 'failed', 'cancelled');
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 2) Tabulka automation_rules (Konfigurace pravidel)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.automation_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,

  name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,

  -- Typ události, kterou engine monitoruje (např. reservation_check_in).
  trigger_event text NOT NULL,
  -- Offset v minutách: záporné = předem, kladné = po události.
  offset_minutes int NOT NULL,

  channel public.automation_channel NOT NULL,

  -- Šablona zprávy pro automatické zaslání.
  template_id uuid NOT NULL REFERENCES public.tenant_message_templates(id) ON DELETE RESTRICT,

  -- Cíl odesílání: guest / staff (upravitelné engine logikou, UI jen mapuje).
  target_entity text NOT NULL,

  -- Volitelný noční klid (pokud je engine implementovaný tak, že respektuje okno).
  quiet_hours_start time,
  quiet_hours_end time,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.automation_rules IS 'Konfigurace automatizačních pravidel pro odesílání zpráv (multitenant).';
COMMENT ON COLUMN public.automation_rules.trigger_event IS 'Trigger event (např. reservation_check_in) používaný Automation engine logikou.';
COMMENT ON COLUMN public.automation_rules.offset_minutes IS 'Offset v minutách vůči triggeru; záporné = předem, kladné = potom.';
COMMENT ON COLUMN public.automation_rules.template_id IS 'ID šablony (tenant_message_templates), která se použije pro vyplnění placeholderů.';
COMMENT ON COLUMN public.automation_rules.target_entity IS 'Cílová entita (guest/staff) - určuje, komu se zpráva cílí.';

ALTER TABLE public.automation_rules ENABLE ROW LEVEL SECURITY;

-- SELECT: tenant vidí pouze vlastní pravidla.
DROP POLICY IF EXISTS automation_rules_select_tenant ON public.automation_rules;
CREATE POLICY automation_rules_select_tenant
  ON public.automation_rules
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

-- INSERT: tenant smí vložit jen pro svůj tenant a template musí patřit stejnému tenantovi.
DROP POLICY IF EXISTS automation_rules_insert_tenant ON public.automation_rules;
CREATE POLICY automation_rules_insert_tenant
  ON public.automation_rules
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.tenant_message_templates t
        WHERE t.id = template_id
          AND t.tenant_id = public.my_tenant_id()
          AND t.deleted_at IS NULL
      )
    )
  );

-- UPDATE: stejná pravidla jako INSERT.
DROP POLICY IF EXISTS automation_rules_update_tenant ON public.automation_rules;
CREATE POLICY automation_rules_update_tenant
  ON public.automation_rules
  FOR UPDATE
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.tenant_message_templates t
        WHERE t.id = template_id
          AND t.tenant_id = public.my_tenant_id()
          AND t.deleted_at IS NULL
      )
    )
  );

-- DELETE: tenant smí smazat jen vlastní pravidla.
DROP POLICY IF EXISTS automation_rules_delete_tenant ON public.automation_rules;
CREATE POLICY automation_rules_delete_tenant
  ON public.automation_rules
  FOR DELETE
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

CREATE INDEX IF NOT EXISTS idx_automation_rules_tenant_id ON public.automation_rules(tenant_id);
CREATE INDEX IF NOT EXISTS idx_automation_rules_trigger_event ON public.automation_rules(trigger_event);
CREATE INDEX IF NOT EXISTS idx_automation_rules_active_tenant ON public.automation_rules(tenant_id, is_active);

-- -----------------------------------------------------------------------------
-- 3) Tabulka automation_message_queue (Fronta / Čekárna)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.automation_message_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,

  rule_id uuid NOT NULL REFERENCES public.automation_rules(id) ON DELETE RESTRICT,

  -- ID rezervace/úkolu (podle entity_type).
  entity_id uuid NOT NULL,
  -- 'reservation' nebo 'task'
  entity_type text NOT NULL CHECK (entity_type IN ('reservation', 'task')),

  -- Kdy se má zpráva odeslat.
  scheduled_for timestamptz NOT NULL,

  status public.automation_queue_status NOT NULL DEFAULT 'pending',

  channel public.automation_channel NOT NULL,
  recipient_contact text,

  -- Předvyplněný payload, který manažer může v UI upravit (před odesláním).
  editable_payload jsonb NOT NULL DEFAULT '{}'::jsonb,

  attempt_count int NOT NULL DEFAULT 0,
  last_error text,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.automation_message_queue IS 'Fronta automatizovaných zpráv čekajících na odeslání.';
COMMENT ON COLUMN public.automation_message_queue.scheduled_for IS 'Naplánovaný čas odeslání v UTC.';
COMMENT ON COLUMN public.automation_message_queue.editable_payload IS 'JSON payload pro UI úpravy před odesláním.';
COMMENT ON COLUMN public.automation_message_queue.status IS 'Stav položky ve frontě pro retry/idempotenci.';

ALTER TABLE public.automation_message_queue ENABLE ROW LEVEL SECURITY;

-- SELECT: tenant vidí jen vlastní položky ve frontě.
DROP POLICY IF EXISTS automation_message_queue_select_tenant ON public.automation_message_queue;
CREATE POLICY automation_message_queue_select_tenant
  ON public.automation_message_queue
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

-- INSERT: tenant smí vložit položku jen pro svůj tenant a rule_id musí patřit stejnému tenantovi.
DROP POLICY IF EXISTS automation_message_queue_insert_tenant ON public.automation_message_queue;
CREATE POLICY automation_message_queue_insert_tenant
  ON public.automation_message_queue
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.automation_rules r
        WHERE r.id = rule_id
          AND r.tenant_id = public.my_tenant_id()
      )
    )
  );

-- UPDATE: stejná pravidla jako INSERT.
DROP POLICY IF EXISTS automation_message_queue_update_tenant ON public.automation_message_queue;
CREATE POLICY automation_message_queue_update_tenant
  ON public.automation_message_queue
  FOR UPDATE
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.automation_rules r
        WHERE r.id = rule_id
          AND r.tenant_id = public.my_tenant_id()
      )
    )
  );

-- DELETE: tenant smí mazat jen vlastní frontové položky.
DROP POLICY IF EXISTS automation_message_queue_delete_tenant ON public.automation_message_queue;
CREATE POLICY automation_message_queue_delete_tenant
  ON public.automation_message_queue
  FOR DELETE
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

CREATE INDEX IF NOT EXISTS idx_automation_queue_tenant_scheduled_for
  ON public.automation_message_queue(tenant_id, scheduled_for);

CREATE INDEX IF NOT EXISTS idx_automation_queue_tenant_status_scheduled
  ON public.automation_message_queue(tenant_id, status, scheduled_for);

CREATE INDEX IF NOT EXISTS idx_automation_queue_tenant_status
  ON public.automation_message_queue(tenant_id, status);

CREATE INDEX IF NOT EXISTS idx_automation_queue_rule_id
  ON public.automation_message_queue(rule_id);

-- -----------------------------------------------------------------------------
-- 4) Tabulka tenant_message_log (Audit log)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tenant_message_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  queue_id uuid NOT NULL REFERENCES public.automation_message_queue(id) ON DELETE CASCADE,

  sent_at timestamptz NOT NULL,
  channel public.automation_channel NOT NULL,

  -- ID z externího provideru (Twilio/SendGrid/atd.) pro reklamace.
  external_api_id text,

  -- 'delivered', 'failed_at_provider' (engine logikou upřesníme).
  status text NOT NULL,

  -- Cena za konkrétní kus zprávy (pro podrobné vyúčtování).
  unit_price numeric(10,4),

  -- Maskované číslo / kontakt (bez plného PII).
  recipient_masked text,

  -- Obsah přesně tak, jak reálně odešel (po renderingu placeholderů).
  content_snapshot text NOT NULL,

  error_details text,

  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.tenant_message_log IS 'Detailní historie odeslaných zpráv (audit + troubleshooting).';
COMMENT ON COLUMN public.tenant_message_log.external_api_id IS 'Externí ID (Twilio/SendGrid), pro dohledání a reklamace.';
COMMENT ON COLUMN public.tenant_message_log.content_snapshot IS 'Text zprávy, který reálně odešel (snapshot po renderingu).';

ALTER TABLE public.tenant_message_log ENABLE ROW LEVEL SECURITY;

-- SELECT: tenant smí číst jen vlastní logy.
DROP POLICY IF EXISTS tenant_message_log_select_tenant ON public.tenant_message_log;
CREATE POLICY tenant_message_log_select_tenant
  ON public.tenant_message_log
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

-- INSERT: log je povolen jen pro tenant a queue_id musí patřit stejnému tenantovi.
DROP POLICY IF EXISTS tenant_message_log_insert_tenant ON public.tenant_message_log;
CREATE POLICY tenant_message_log_insert_tenant
  ON public.tenant_message_log
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND EXISTS (
        SELECT 1
        FROM public.automation_message_queue q
        WHERE q.id = queue_id
          AND q.tenant_id = public.my_tenant_id()
      )
    )
  );

-- UPDATE: logy jsou audit; obvykle se nemění. Povolení ponecháváme konzervativně.
DROP POLICY IF EXISTS tenant_message_log_update_tenant ON public.tenant_message_log;
CREATE POLICY tenant_message_log_update_tenant
  ON public.tenant_message_log
  FOR UPDATE
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  )
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

-- DELETE: logy audit; standardně povoleno jen vlastníkovi.
DROP POLICY IF EXISTS tenant_message_log_delete_tenant ON public.tenant_message_log;
CREATE POLICY tenant_message_log_delete_tenant
  ON public.tenant_message_log
  FOR DELETE
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

CREATE INDEX IF NOT EXISTS idx_tenant_message_log_tenant_sent_at
  ON public.tenant_message_log(tenant_id, sent_at);

CREATE INDEX IF NOT EXISTS idx_tenant_message_log_queue_id
  ON public.tenant_message_log(queue_id);

-- -----------------------------------------------------------------------------
-- 5) Tabulka tenant_usage_monthly (Fakturační agregace)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tenant_usage_monthly (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,

  -- 'YYYY-MM' (např. 2026-03) – stejný formát použijeme i v reportingu.
  billing_month text NOT NULL,

  channel public.automation_channel NOT NULL,
  sent_count int NOT NULL DEFAULT 0,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT uq_tenant_usage_monthly UNIQUE (tenant_id, billing_month, channel)
);

COMMENT ON TABLE public.tenant_usage_monthly IS 'Měsíční agregace odeslaných zpráv pro billing (overage).';
COMMENT ON COLUMN public.tenant_usage_monthly.billing_month IS 'Formát YYYY-MM pro fakturační období.';

ALTER TABLE public.tenant_usage_monthly ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_usage_monthly_select_tenant ON public.tenant_usage_monthly;
CREATE POLICY tenant_usage_monthly_select_tenant
  ON public.tenant_usage_monthly
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

DROP POLICY IF EXISTS tenant_usage_monthly_insert_tenant ON public.tenant_usage_monthly;
CREATE POLICY tenant_usage_monthly_insert_tenant
  ON public.tenant_usage_monthly
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

DROP POLICY IF EXISTS tenant_usage_monthly_update_tenant ON public.tenant_usage_monthly;
CREATE POLICY tenant_usage_monthly_update_tenant
  ON public.tenant_usage_monthly
  FOR UPDATE
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  )
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

DROP POLICY IF EXISTS tenant_usage_monthly_delete_tenant ON public.tenant_usage_monthly;
CREATE POLICY tenant_usage_monthly_delete_tenant
  ON public.tenant_usage_monthly
  FOR DELETE
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

CREATE INDEX IF NOT EXISTS idx_tenant_usage_monthly_tenant_month
  ON public.tenant_usage_monthly(tenant_id, billing_month);

-- =============================================================================
-- Konec migrace
-- =============================================================================

