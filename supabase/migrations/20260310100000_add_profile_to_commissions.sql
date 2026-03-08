-- =============================================================================
-- FalcoNest – Provize může dostat i zaměstnanec (ne pouze klient)
-- =============================================================================
-- PROČ: Uklízečka může sehnat klienta na Facebooku a dostat provizi – nechceme
-- ji duplikovat v tabulce klientů. Sloupec profile_id umožní přiřadit provizi
-- přímo zaměstnanci.
-- Pravidlo: Vyplněno právě jedno z (client_id, profile_id).
-- =============================================================================

-- 1. Přidat profile_id (nullable, FK na profiles)
ALTER TABLE public.task_commissions
  ADD COLUMN IF NOT EXISTS profile_id uuid REFERENCES public.profiles(id) ON DELETE RESTRICT;

COMMENT ON COLUMN public.task_commissions.profile_id IS 'Zaměstnanec jako příjemce provize – alternativa k client_id. Vyplněno právě jedno z (client_id, profile_id).';

-- 2. client_id zpřístupnit jako nullable (existující záznamy mají client_id)
ALTER TABLE public.task_commissions
  ALTER COLUMN client_id DROP NOT NULL;

-- 3. Kontrola integrity: právě jedno z (client_id, profile_id) musí být vyplněno
ALTER TABLE public.task_commissions
  DROP CONSTRAINT IF EXISTS task_commissions_recipient_check;

ALTER TABLE public.task_commissions
  ADD CONSTRAINT task_commissions_recipient_check
  CHECK (
    (client_id IS NOT NULL AND profile_id IS NULL)
    OR (client_id IS NULL AND profile_id IS NOT NULL)
  );

-- 4. Index pro vyhledávání provizí podle profile_id
CREATE INDEX IF NOT EXISTS idx_task_commissions_profile_id ON public.task_commissions(profile_id);
