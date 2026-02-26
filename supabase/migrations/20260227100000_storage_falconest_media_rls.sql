-- =============================================================================
-- FalcoNest – RLS politiky pro Supabase Storage bucket falconest_media
-- =============================================================================
-- Bucket slouží pro účtenky, fotky škod. Politiky se vytváří nad storage.objects.
-- INSERT: pouze authenticated. SELECT: pro čtení (public bucket + Storage API).
-- =============================================================================

-- Politika 1: Zápis (INSERT) – pouze přihlášení uživatelé
CREATE POLICY "falconest_media_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'falconest_media');

-- Politika 2: Čtení (SELECT) – pro zobrazení přes Storage API
CREATE POLICY "falconest_media_select"
ON storage.objects
FOR SELECT
USING (bucket_id = 'falconest_media');
