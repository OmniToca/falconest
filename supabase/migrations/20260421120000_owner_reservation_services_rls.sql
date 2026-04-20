-- =============================================================================
-- FalcoNest – RLS SELECT pro majitele (property_owner) na reservation_services
-- =============================================================================
-- PROBLÉM: Obecná politika reservation_services_select používá tenant_id = my_tenant_id().
-- U role property_owner je profiles.tenant_id často NULL → majitel nevidí řádky
-- reservation_services → Dart buildBillingReservationServiceMaps vrací prázdné mapy,
-- billingChargedPriceAndPayerForTask spadne do fallbacku a špatně odvodí plátce (např. guest).
--
-- ŘEŠENÍ: Stejný vzor jako tasks_property_owner_select_own_apartments – majitel čte jen
-- služby u rezervací na apartmánech z apartment_owners (owner_id = jeho profiles.id).
-- =============================================================================

DROP POLICY IF EXISTS "reservation_services_property_owner_select" ON public.reservation_services;

CREATE POLICY "reservation_services_property_owner_select"
  ON public.reservation_services
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1
      FROM public.reservations r
      INNER JOIN public.apartment_owners ao ON ao.apartment_id = r.apartment_id
      WHERE r.id = reservation_services.reservation_id
        AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
        AND ao.deleted_at IS NULL
        AND r.deleted_at IS NULL
    )
  );

COMMENT ON POLICY "reservation_services_property_owner_select" ON public.reservation_services IS
  'SELECT: property_owner vidí řádky reservation_services jen pro rezervace na vlastněných bytech (apartment_owners), včetně tenant_id shody.';

NOTIFY pgrst, 'reload schema';
