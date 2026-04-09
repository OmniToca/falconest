-- =============================================================================
-- FalcoNest – tenant_message_log: směr zprávy (outbound / inbound) + text od hosta
-- =============================================================================
-- PROČ: Příchozí SMS/WhatsApp z Twilia ukládáme jako inbound; tyto řádky nemají
-- vazbu na `automation_message_queue`, proto `queue_id` musí být NULLABLE.
-- =============================================================================

ALTER TABLE public.tenant_message_log
  ADD COLUMN IF NOT EXISTS direction text NOT NULL DEFAULT 'outbound';

ALTER TABLE public.tenant_message_log
  DROP CONSTRAINT IF EXISTS tenant_message_log_direction_check;

ALTER TABLE public.tenant_message_log
  ADD CONSTRAINT tenant_message_log_direction_check
  CHECK (direction IN ('outbound', 'inbound'));

ALTER TABLE public.tenant_message_log
  ADD COLUMN IF NOT EXISTS inbound_text text NULL;

COMMENT ON COLUMN public.tenant_message_log.direction IS
  'Směr: outbound = odesláno systémem, inbound = příchozí odpověď od hosta (Twilio).';

COMMENT ON COLUMN public.tenant_message_log.inbound_text IS
  'Text příchozí zprávy od hosta (jen u direction = inbound).';

-- Příchozí řádky nepatří do fronty automatizací.
ALTER TABLE public.tenant_message_log
  ALTER COLUMN queue_id DROP NOT NULL;

-- PROČ: INSERT policy musí povolit inbound záznamy bez queue_id (outbound stále vyžaduje frontu).
DROP POLICY IF EXISTS tenant_message_log_insert_tenant ON public.tenant_message_log;
CREATE POLICY tenant_message_log_insert_tenant
  ON public.tenant_message_log
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND (
        (
          direction = 'inbound'
          AND queue_id IS NULL
        )
        OR (
          direction = 'outbound'
          AND EXISTS (
            SELECT 1
            FROM public.automation_message_queue q
            WHERE q.id = queue_id
              AND q.tenant_id = public.my_tenant_id()
          )
        )
      )
    )
  );
