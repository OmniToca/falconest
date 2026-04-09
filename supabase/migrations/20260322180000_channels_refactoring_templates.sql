-- =============================================================================
-- FalcoNest – tenant_message_templates: čistý refaktoring kanálů a šablon (Fáze 1+2)
-- =============================================================================
-- BEZ zpětné kompatibility: legacy sloupce body + language_code jsou odstraněny.
-- Pořadí dle zadání:
--   1) DROP CHECK na channel (smyčka)
--   2) DROP legacy sloupců
--   3) sjednocení dat + nový CHECK
--   4) nové sloupce email_subject + translations
--   5) indexy
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0) Index závislý na language_code – musí pryč před DROP COLUMN
-- -----------------------------------------------------------------------------
DROP INDEX IF EXISTS idx_tenant_message_templates_tenant_channel_language_active;

-- -----------------------------------------------------------------------------
-- 1) DROP starého CHECK constraintu pro sloupec `channel`
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  v_constraint_name text;
BEGIN
  FOR v_constraint_name IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname = 'tenant_message_templates'
      AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) ILIKE '%channel%'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.tenant_message_templates DROP CONSTRAINT IF EXISTS %I',
      v_constraint_name
    );
  END LOOP;
END $$;

-- -----------------------------------------------------------------------------
-- 2) Vyčištění tabulky: legacy sloupce
-- -----------------------------------------------------------------------------
ALTER TABLE public.tenant_message_templates
  DROP COLUMN IF EXISTS body,
  DROP COLUMN IF EXISTS language_code;

-- -----------------------------------------------------------------------------
-- 3) Sjednocení dat a nový CHECK pro channel IN ('sms', 'email', 'whatsapp')
-- -----------------------------------------------------------------------------
UPDATE public.tenant_message_templates
SET channel = 'whatsapp'
WHERE channel = 'whatsapp_link';

UPDATE public.tenant_message_templates
SET channel = 'whatsapp'
WHERE channel IS NULL OR channel NOT IN ('sms', 'email', 'whatsapp');

ALTER TABLE public.tenant_message_templates
  ADD CONSTRAINT tenant_message_templates_channel_check
  CHECK (channel IN ('sms', 'email', 'whatsapp'));

-- -----------------------------------------------------------------------------
-- 4) Nové sloupce
-- -----------------------------------------------------------------------------
ALTER TABLE public.tenant_message_templates
  ADD COLUMN IF NOT EXISTS email_subject text,
  ADD COLUMN IF NOT EXISTS translations jsonb;

COMMENT ON COLUMN public.tenant_message_templates.email_subject IS
  'Předmět e-mailu pro channel=email. U SMS/WhatsApp se ignoruje.';

COMMENT ON COLUMN public.tenant_message_templates.translations IS
  'Vícejazyčný obsah šablony (jsonb): klíč = jazyk (cs, en, es), hodnota = { body, subject?, name? }.';

-- -----------------------------------------------------------------------------
-- 5) Indexy
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_tenant_message_templates_tenant_channel_active
  ON public.tenant_message_templates (tenant_id, channel)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_tenant_message_templates_translations_gin
  ON public.tenant_message_templates USING gin (translations)
  WHERE deleted_at IS NULL;
