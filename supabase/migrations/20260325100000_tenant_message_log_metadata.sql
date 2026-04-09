-- =============================================================================
-- FalcoNest – tenant_message_log.metadata (JSONB)
-- =============================================================================
-- PROČ: Edge `automation-dispatch` ukládá např. `num_segments` z Twilio odpovědi pro
-- fakturaci podle reálných SMS segmentů, bez nových sloupců na každé pole.
-- =============================================================================

ALTER TABLE public.tenant_message_log
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.tenant_message_log.metadata IS
  'Doplňková data outbound zprávy (např. num_segments od Twilio).';
