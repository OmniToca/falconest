-- Přidá preferovaný jazyk komunikace do CRM klientů.
-- PROČ: Externí úkoly bez rezervace potřebují spolehlivý zdroj jazyka pro filtr šablon.

ALTER TABLE public.clients
ADD COLUMN IF NOT EXISTS language_code varchar(2) DEFAULT 'en';

COMMENT ON COLUMN public.clients.language_code IS
'Preferovaný jazyk komunikace klienta (ISO-2), např. cs/en/es/de/fr.';
