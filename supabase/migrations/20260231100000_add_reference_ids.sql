-- Lidsky čitelné identifikátory pro podporu, importy a zákaznickou komunikaci.
-- Apartments: ruční kód (např. SUN-01) pro CSV import a rychlou identifikaci bytu.
-- Reservations + Tasks: automaticky generované reference_number na straně klienta (offline-first).

ALTER TABLE apartments ADD COLUMN IF NOT EXISTS code text;
ALTER TABLE reservations ADD COLUMN IF NOT EXISTS reference_number text;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS reference_number text;
