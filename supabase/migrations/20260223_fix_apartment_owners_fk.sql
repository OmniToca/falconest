-- =============================================================================
-- BUGFIX: Doplnění chybějící FK relace pro JOIN a vyčištění Supabase cache.
-- =============================================================================
-- Chyba PGRST200: PostgREST nenašel vztah mezi apartment_owners a profiles.
-- Příčina: Tabulka apartment_owners měla owner_id bez explicitního FK na profiles(id),
-- nebo byl FK odstraněn. Bez FK PostgREST nemůže provést embed (např. .select('*, profiles(*)')).
--
-- Tento skript: přidá FK apartment_owners.owner_id → profiles(id).
-- Po změně schématu je nutné notifikovat PostgREST pro reload cache.
-- =============================================================================

ALTER TABLE public.apartment_owners
  DROP CONSTRAINT IF EXISTS apartment_owners_owner_id_fkey;

ALTER TABLE public.apartment_owners
  ADD CONSTRAINT apartment_owners_owner_id_fkey
  FOREIGN KEY (owner_id)
  REFERENCES public.profiles(id)
  ON DELETE CASCADE;

-- Vyčištění Supabase/PostgREST schema cache – bez tohoto zůstává stará metadata.
NOTIFY pgrst, 'reload schema';
