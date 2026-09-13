-- =============================================================================
-- P0 bezpečnost: Storage falconest_media – private bucket + path-scoped RLS
-- =============================================================================
-- PROČ: Původní politiky dovolovaly libovolnému authenticated upload a světu
-- číst všechny soubory. Cesta v aplikaci je `tenant_id/modul/soubor` – RLS musí
-- vynutit, že první složka = my_tenant_id() (nebo super_admin).
-- =============================================================================

-- Bucket privátní (signed URL místo veřejného getPublicUrl).
UPDATE storage.buckets
SET public = false
WHERE id = 'falconest_media';

DROP POLICY IF EXISTS "falconest_media_insert" ON storage.objects;
DROP POLICY IF EXISTS "falconest_media_select" ON storage.objects;
DROP POLICY IF EXISTS "falconest_media_update" ON storage.objects;
DROP POLICY IF EXISTS "falconest_media_delete" ON storage.objects;

-- INSERT: přihlášený uživatel jen do složky svého tenanta (první segment cesty).
CREATE POLICY "falconest_media_insert_tenant"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'falconest_media'
  AND (
    public.is_super_admin()
    OR (storage.foldername(name))[1] = public.my_tenant_id()::text
  )
);

-- SELECT: jen vlastní tenant (nebo super_admin) – žádné veřejné čtení.
CREATE POLICY "falconest_media_select_tenant"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'falconest_media'
  AND (
    public.is_super_admin()
    OR (storage.foldername(name))[1] = public.my_tenant_id()::text
  )
);

-- UPDATE / DELETE: stejný scope (přepsání podpisu, mazání starých médií).
CREATE POLICY "falconest_media_update_tenant"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'falconest_media'
  AND (
    public.is_super_admin()
    OR (storage.foldername(name))[1] = public.my_tenant_id()::text
  )
)
WITH CHECK (
  bucket_id = 'falconest_media'
  AND (
    public.is_super_admin()
    OR (storage.foldername(name))[1] = public.my_tenant_id()::text
  )
);

CREATE POLICY "falconest_media_delete_tenant"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'falconest_media'
  AND (
    public.is_super_admin()
    OR (storage.foldername(name))[1] = public.my_tenant_id()::text
  )
);

COMMENT ON POLICY "falconest_media_insert_tenant" ON storage.objects IS
  'P0: upload jen do tenant_id/… nebo super_admin.';
COMMENT ON POLICY "falconest_media_select_tenant" ON storage.objects IS
  'P0: čtení jen vlastního tenanta – bucket je private, klient používá signed URL.';
