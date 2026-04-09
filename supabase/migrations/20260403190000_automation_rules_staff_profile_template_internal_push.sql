-- =============================================================================
-- FalcoNest – internal_push: cílový staff profil + šablona stejného kanálu
-- =============================================================================
-- PROČ: Pravidla s kanálem internal_push posílají FCM dispečerovi (profiles.id),
-- ne hostovi na telefon. Sloupec staff_profile_id určuje příjemce; šablony
-- s channel = internal_push drží volitelný text pro náhled ve frontě (dispatch
-- titulek/tělo generuje sám z rezervace).
-- =============================================================================

ALTER TABLE public.automation_rules
  ADD COLUMN IF NOT EXISTS staff_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.automation_rules.staff_profile_id IS
  'UUID profilu příjemce pro kanál internal_push (FCM). Používejte s target_entity = staff.';

ALTER TABLE public.tenant_message_templates
  DROP CONSTRAINT IF EXISTS tenant_message_templates_channel_check;

ALTER TABLE public.tenant_message_templates
  ADD CONSTRAINT tenant_message_templates_channel_check
  CHECK (channel IN ('sms', 'email', 'whatsapp', 'internal_push'));
