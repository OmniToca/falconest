-- =============================================================================
-- FalcoNest – Kanál internal_push (interní FCM místo WhatsApp / Meta API)
-- =============================================================================
-- PROČ: Položky ve frontě `automation_message_queue` s tímto kanálem odbaví
-- Edge `automation-dispatch` přes FCM na tokeny v `user_devices`, nikoli přes Twilio.
-- Hodnota enumu je `internal_push` (PostgreSQL konvence); v aplikaci lze mapovat z INTERNAL_PUSH.
-- =============================================================================

ALTER TYPE public.automation_channel ADD VALUE IF NOT EXISTS 'internal_push';

ALTER TABLE public.platform_messaging_rates
  DROP CONSTRAINT IF EXISTS platform_messaging_rates_channel_check;

ALTER TABLE public.platform_messaging_rates
  ADD CONSTRAINT platform_messaging_rates_channel_check
  CHECK (channel IN ('sms', 'whatsapp', 'email', 'internal_push'));

INSERT INTO public.platform_messaging_rates (channel, price_eur, valid_from)
SELECT 'internal_push', 0, now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.platform_messaging_rates r WHERE r.channel = 'internal_push'
);
