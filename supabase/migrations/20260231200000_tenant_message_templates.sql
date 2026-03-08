-- =============================================================================
-- FalcoNest – Modul Communication: Tabulka tenant_message_templates
-- =============================================================================
-- Šablony zpráv pro řidiče (WhatsApp Deep Links, budoucí SMS). Každá agentura
-- si vytváří vlastní texty s placeholdery {guest_name}, {flight_number} atd.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.tenant_message_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  key text NOT NULL,
  name text NOT NULL,
  body text NOT NULL,
  channel text DEFAULT 'whatsapp_link' CHECK (channel IN ('whatsapp_link', 'sms', 'email')),
  language_code text,
  trigger_context text,
  order_index integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

COMMENT ON TABLE public.tenant_message_templates IS 'Šablony zpráv pro komunikaci s hosty – WhatsApp, SMS, e-mail. Řidiči je používají offline.';
COMMENT ON COLUMN public.tenant_message_templates.key IS 'Systémový identifikátor šablony (např. transfer_48h, at_airport).';
COMMENT ON COLUMN public.tenant_message_templates.name IS 'Lidský název pro UI (např. „48h před transferem“).';
COMMENT ON COLUMN public.tenant_message_templates.body IS 'Text s placeholdery: {guest_name}, {flight_number}, {address}, {keybox}, …';
COMMENT ON COLUMN public.tenant_message_templates.channel IS 'Kanál odeslání: whatsapp_link (Deep Link), sms, email – pro budoucí rozšíření.';
COMMENT ON COLUMN public.tenant_message_templates.language_code IS 'i18n: NULL = výchozí, cs/en/es – verze pro jazyky hostů.';
COMMENT ON COLUMN public.tenant_message_templates.trigger_context IS 'Volitelně: transfer, check_in, check_out – filtrování v UI řidiče.';
COMMENT ON COLUMN public.tenant_message_templates.order_index IS 'Pořadí v UI (0 = první, vyšší = níže).';
COMMENT ON COLUMN public.tenant_message_templates.deleted_at IS 'Soft delete: NULL = aktivní šablona; NOT NULL = skrytá.';

CREATE INDEX IF NOT EXISTS idx_tenant_message_templates_tenant_id ON public.tenant_message_templates(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_message_templates_deleted_at ON public.tenant_message_templates(deleted_at);

ALTER TABLE public.tenant_message_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tenant_message_templates_select"
  ON public.tenant_message_templates FOR SELECT
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

CREATE POLICY "tenant_message_templates_insert"
  ON public.tenant_message_templates FOR INSERT
  WITH CHECK (public.is_super_admin() OR tenant_id = public.my_tenant_id());

CREATE POLICY "tenant_message_templates_update"
  ON public.tenant_message_templates FOR UPDATE
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());

CREATE POLICY "tenant_message_templates_delete"
  ON public.tenant_message_templates FOR DELETE
  USING (public.is_super_admin() OR tenant_id = public.my_tenant_id());
