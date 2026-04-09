-- Jazyk komunikace s hostem (pro filtrování message templates v Admin UI).
ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS guest_language varchar(2) DEFAULT 'en';

COMMENT ON COLUMN reservations.guest_language IS 'Jazyk šablon pro komunikaci s hostem (např. en/cs/es). NULL = fallback en (UI).';

