-- =============================================================================
-- FalcoNest – Propojení tabulky clients s profiles (Varianta D)
-- =============================================================================
-- PROČ: CRM klient (clients) může mít přiřazený přihlašovací profil (profiles)
-- pro Klientský portál majitelů. Umožňuje propojení modulů Klienti a Apartmány –
-- majitel vytvořený v CRM lze přiřadit k apartmánu přes apartment_owners (owner_id).
--
-- Sloupec profile_id je NULLABLE – externí klienti a agentury nemusejí mít profil.
-- ON DELETE SET NULL – při smazání profilu zůstane klient v CRM (ztratí jen přístup).
-- =============================================================================

ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.clients.profile_id IS 'Propojení CRM klienta s přihlašovacím profilem (Klientský portál majitelů). NULL = klient nemá přístup do systému.';

CREATE INDEX IF NOT EXISTS idx_clients_profile_id ON public.clients(profile_id) WHERE profile_id IS NOT NULL;
