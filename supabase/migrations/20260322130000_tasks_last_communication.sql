-- Indikátor poslední WhatsApp zprávy u úkolu (denormalizace z audit logu).
ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS last_communication_template_id uuid,
  ADD COLUMN IF NOT EXISTS last_communication_template_context text,
  ADD COLUMN IF NOT EXISTS last_communication_at timestamptz;

COMMENT ON COLUMN tasks.last_communication_template_id IS 'ID šablony (tenant_message_templates.id) použitée pro poslední WhatsApp odkaz.';
COMMENT ON COLUMN tasks.last_communication_template_context IS 'trigger_context šablony (např. check_in, transfer_in).';
COMMENT ON COLUMN tasks.last_communication_at IS 'Čas posledního vygenerování WhatsApp odkazu.';

-- Rezervace: přidání ID šablony pro přesnou shodu „která šablona byla odeslána“.
ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS last_communication_template_id uuid;

COMMENT ON COLUMN reservations.last_communication_template_id IS 'ID šablony (tenant_message_templates.id) použitée pro poslední WhatsApp odkaz.';
