-- -----------------------------------------------------------------------------
-- FalcoNest – notification_preferences: majitel (property_owner) – události z terénu
-- PROČ: Klientský portál umožní zapnout/vypnout kanály (web zvoneček, push, e-mail)
-- pro zahájení/dokončení úkolu a vybrání hotovosti. WhatsApp se nepoužívá.
-- Výchozí true = konzistentně s ostatními kanály matice (opt-out).
-- -----------------------------------------------------------------------------

ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS owner_task_started_web boolean NOT NULL DEFAULT true;
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS owner_task_started_push boolean NOT NULL DEFAULT true;
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS owner_task_started_email boolean NOT NULL DEFAULT true;
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS owner_task_completed_web boolean NOT NULL DEFAULT true;
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS owner_task_completed_push boolean NOT NULL DEFAULT true;
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS owner_task_completed_email boolean NOT NULL DEFAULT true;
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS owner_cash_collected_web boolean NOT NULL DEFAULT true;
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS owner_cash_collected_push boolean NOT NULL DEFAULT true;
ALTER TABLE public.notification_preferences
  ADD COLUMN IF NOT EXISTS owner_cash_collected_email boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.notification_preferences.owner_task_started_web IS
  'Majitel: zahájení úklidu/práce u jeho bytu – in-app zvoneček.';
COMMENT ON COLUMN public.notification_preferences.owner_task_started_push IS
  'Majitel: zahájení práce – push (FCM / Web Push).';
COMMENT ON COLUMN public.notification_preferences.owner_task_started_email IS
  'Majitel: zahájení práce – e-mail.';

COMMENT ON COLUMN public.notification_preferences.owner_task_completed_web IS
  'Majitel: dokončení práce – in-app zvoneček.';
COMMENT ON COLUMN public.notification_preferences.owner_task_completed_push IS
  'Majitel: dokončení práce – push.';
COMMENT ON COLUMN public.notification_preferences.owner_task_completed_email IS
  'Majitel: dokončení práce – e-mail.';

COMMENT ON COLUMN public.notification_preferences.owner_cash_collected_web IS
  'Majitel: vybrání hotovosti od klienta – in-app zvoneček.';
COMMENT ON COLUMN public.notification_preferences.owner_cash_collected_push IS
  'Majitel: vybrání hotovosti – push.';
COMMENT ON COLUMN public.notification_preferences.owner_cash_collected_email IS
  'Majitel: vybrání hotovosti – e-mail.';
