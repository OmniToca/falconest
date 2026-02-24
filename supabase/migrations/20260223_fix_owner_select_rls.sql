-- =============================================================================
-- BUGFIX: Oprava RLS politik pro pozvané majitele. Místo auth.uid() se musí
-- ověřovat shoda s profiles.id. U ghost profilů (po registraci) je profiles.id
-- odlišné od auth.users.id – owner_id v apartment_owners odkazuje na profiles.id.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. apartment_owners – property_owner smí číst jen své záznamy
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "apartment_owners_property_owner_select_own" ON public.apartment_owners;

CREATE POLICY "apartment_owners_property_owner_select_own"
  ON public.apartment_owners
  FOR SELECT
  TO authenticated
  USING (
    owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
  );

-- -----------------------------------------------------------------------------
-- 2. apartments – property_owner smí číst pouze byty přiřazené v apartment_owners
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "apartments_property_owner_select_own" ON public.apartments;

CREATE POLICY "apartments_property_owner_select_own"
  ON public.apartments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM public.apartment_owners ao
      WHERE ao.apartment_id = apartments.id
      AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
      AND ao.deleted_at IS NULL
    )
  );

-- -----------------------------------------------------------------------------
-- 3. tasks – property_owner smí číst úkoly u svých bytů
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "tasks_property_owner_select_own_apartments" ON public.tasks;

CREATE POLICY "tasks_property_owner_select_own_apartments"
  ON public.tasks
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM public.apartment_owners ao
      WHERE ao.apartment_id = tasks.apartment_id
      AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
      AND ao.deleted_at IS NULL
    )
  );

-- -----------------------------------------------------------------------------
-- 4. tasks – property_owner smí vkládat úkoly pro své byty (z rezervací)
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "tasks_property_owner_insert_own_apartments" ON public.tasks;

CREATE POLICY "tasks_property_owner_insert_own_apartments"
  ON public.tasks
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM public.apartment_owners ao
      WHERE ao.apartment_id = tasks.apartment_id
      AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
      AND ao.deleted_at IS NULL
    )
  );

-- -----------------------------------------------------------------------------
-- 5. reservations – property_owner smí číst rezervace u svých bytů
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "reservations_property_owner_select" ON public.reservations;

CREATE POLICY "reservations_property_owner_select"
  ON public.reservations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM public.apartment_owners ao
      WHERE ao.apartment_id = reservations.apartment_id
      AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
      AND ao.deleted_at IS NULL
    )
  );

-- -----------------------------------------------------------------------------
-- 6. reservations – property_owner smí vkládat rezervace jen pro své byty
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "reservations_property_owner_insert" ON public.reservations;

CREATE POLICY "reservations_property_owner_insert"
  ON public.reservations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM public.apartment_owners ao
      WHERE ao.apartment_id = reservations.apartment_id
      AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
      AND ao.deleted_at IS NULL
    )
  );

-- -----------------------------------------------------------------------------
-- Reload PostgREST schema cache
-- -----------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
