-- FalcoNest – sloupec last_sign_in_at v profiles pro Health indikátor na Super Admin dashboardu.
-- Hodnota: MAX(profiles.last_sign_in_at) podle tenant_id = „poslední aktivita“ agentury.
-- Aplikace nebo trigger může synchronizovat z auth.users.last_sign_in_at při přihlášení.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS last_sign_in_at TIMESTAMPTZ DEFAULT NULL;

COMMENT ON COLUMN public.profiles.last_sign_in_at IS 'Poslední přihlášení uživatele (může být sync z auth.users). Pro Super Admin dashboard: zdraví agentury (Online dnes / X dní zpět / Neaktivní).';
