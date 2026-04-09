-- Indikátor poslední připravené WhatsApp zprávy (denormalizace z audit logu).
-- PROČ: UI může zobrazit „Check-in odeslán“ bez dotazování audit_logs (výkon pro 1000+ uživatelů).
ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS last_communication_template_context text,
  ADD COLUMN IF NOT EXISTS last_communication_at timestamptz;

COMMENT ON COLUMN reservations.last_communication_template_context IS 'trigger_context použité šablony (např. check_in, transfer_in). NULL = nebylo odesláno.';
COMMENT ON COLUMN reservations.last_communication_at IS 'Čas posledního vygenerování WhatsApp odkazu (úmysl odeslání).';
