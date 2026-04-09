-- =============================================================================
-- FalcoNest – RLS pro majitele: SELECT na tenant_services a apartment_services
-- =============================================================================
-- PROBLÉM: Role property_owner nemá přístup k těmto tabulkám – podmínka
-- tenant_id = my_tenant_id() u majitele (profiles.tenant_id typicky NULL) nikdy
-- neprojde. Majitel tak v Klientské zóně neviděl služby u svých bytů.
--
-- ŘEŠENÍ: Dvě nové SELECT politiky – majitel smí číst pouze:
-- 1) tenant_services – katalog služeb agentur, které spravují alespoň jeden jeho byt.
-- 2) apartment_services – řádky u bytů, které má v apartment_owners (owner_id = jeho profil).
--
-- REF: Analýza / rentgen načítání služeb (Owner Portal), návrh RLS politik.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. tenant_services – majitel čte katalog služeb agentury spravující jeho byty
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "tenant_services_property_owner_select" ON public.tenant_services;

CREATE POLICY "tenant_services_property_owner_select"
  ON public.tenant_services
  FOR SELECT
  TO authenticated
  USING (
    (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'property_owner'
    AND tenant_id IN (
      SELECT DISTINCT a.tenant_id
      FROM public.apartments a
      INNER JOIN public.apartment_owners ao ON ao.apartment_id = a.id AND ao.deleted_at IS NULL
      WHERE ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
    )
  );

COMMENT ON POLICY "tenant_services_property_owner_select" ON public.tenant_services IS
  'SELECT: Majitel (property_owner) smí číst tenant_services jen pro agentury (tenant_id), které spravují alespoň jeden jeho byt (apartment_owners).';

-- -----------------------------------------------------------------------------
-- 2. apartment_services – majitel čte služby jen u svých bytů
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "apartment_services_property_owner_select" ON public.apartment_services;

CREATE POLICY "apartment_services_property_owner_select"
  ON public.apartment_services
  FOR SELECT
  TO authenticated
  USING (
    (SELECT role FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = 'property_owner'
    AND apartment_id IN (
      SELECT ao.apartment_id
      FROM public.apartment_owners ao
      WHERE ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
        AND ao.deleted_at IS NULL
    )
  );

COMMENT ON POLICY "apartment_services_property_owner_select" ON public.apartment_services IS
  'SELECT: Majitel (property_owner) smí číst apartment_services pouze u bytů, které má v apartment_owners (vlastní).';
