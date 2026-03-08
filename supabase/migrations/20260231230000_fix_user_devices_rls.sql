-- =============================================================================
-- FalcoNest – Oprava RLS pro user_devices (UPSERT při přepnutí uživatele)
-- =============================================================================
-- Problém: Při přihlášení jiného uživatele na stejném zařízení (stejný FCM token)
-- původní UPDATE policy blokovala přepsání řádku (profile_id patřil předchozímu uživateli).
-- Řešení: UPDATE umožní přepsat řádek, pokud nový profile_id = aktuální uživatel.
-- =============================================================================

-- Odstranění starých politik pro INSERT a UPDATE
DROP POLICY IF EXISTS "user_devices_insert" ON public.user_devices;
DROP POLICY IF EXISTS "user_devices_update" ON public.user_devices;

-- -----------------------------------------------------------------------------
-- Nová INSERT politika
-- -----------------------------------------------------------------------------
-- Povoluje zápis nového tokenu, pokud je uživatel přihlášen a zapisuje vlastní
-- profile_id a tenant_id (z profilu odpovídajícího auth.uid()).
CREATE POLICY "user_devices_insert"
  ON public.user_devices FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
      AND tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
    )
  );

-- -----------------------------------------------------------------------------
-- Nová UPDATE politika
-- -----------------------------------------------------------------------------
-- Povoluje přepsat existující řádek (i když patřil jinému uživateli), pouze pokud
-- si ho nový uživatel přiřazuje k sobě (NEW.profile_id a NEW.tenant_id = aktuální profil).
-- Tím se vyřeší situace, kdy se na stejném mobilu přihlásí jiný uživatel – token
-- se přiřadí novému profilu.
CREATE POLICY "user_devices_update"
  ON public.user_devices FOR UPDATE
  USING (true)
  WITH CHECK (
    public.is_super_admin()
    OR (
      profile_id = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
      AND tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
    )
  );
