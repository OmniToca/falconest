-- FalcoNest – úprava tasks.assigned_to pro podporu profiles i invitations.
--
-- Problém: tasks.assigned_to má FK REFERENCES auth.users(id), takže nelze uložit
-- invitation UUID (invitations.id). Pending uživatelé (pozvánky) tak nemohou být přiřazeni.
--
-- Řešení: Odebrat FK constraint, sloupec zůstane UUID – může obsahovat profile.id
-- (auth.users) NEBO invitation.id (invitations). Aplikace řeší rozlišení podle kontextu.
--
-- Spusť v Supabase SQL Editoru.

-- 1. Odebrat stávající FK constraint (název se může lišit podle Supabase – zkontroluj pg_constraint)
ALTER TABLE public.tasks
  DROP CONSTRAINT IF EXISTS tasks_assigned_to_fkey;

-- Alternativně, pokud má FK jiný název:
-- SELECT conname FROM pg_constraint WHERE conrelid = 'public.tasks'::regclass AND contype = 'f';
-- Pak: ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS <conname>;

-- 2. Sloupec assigned_to zůstává UUID – žádná nová FK. Aplikace ukládá:
--    - profile.id pro aktivní uživatele (z profiles)
--    - invitation.id pro pending uživatele (z invitations)

COMMENT ON COLUMN public.tasks.assigned_to IS 'UUID – profile.id (aktivní) nebo invitation.id (čekající na přihlášení). Bez FK pro flexibilitu.';
