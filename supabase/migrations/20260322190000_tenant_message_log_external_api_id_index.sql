-- Index pro rychlé vyhledání řádku podle Twilio Message SID ve webhooku
-- (edge funkce `twilio-webhook` dělá UPDATE WHERE external_api_id = MessageSid).
CREATE INDEX IF NOT EXISTS idx_tenant_message_log_external_api_id
  ON public.tenant_message_log (external_api_id)
  WHERE external_api_id IS NOT NULL;

COMMENT ON COLUMN public.tenant_message_log.status IS
  'Stav doručení: sent (odesláno providerovi, čeká na webhook), delivered/read (Twilio callback), failed_at_provider (chyba).';
