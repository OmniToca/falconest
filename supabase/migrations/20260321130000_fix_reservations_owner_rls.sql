-- Corrective Security Patch: reservations_select nesmí platit pro roli property_owner.
-- Majitel smí číst rezervace výhradně přes politiku reservations_property_owner_select
-- (apartment v apartment_owners). Tím zamezíme úniku dat mezi majiteli v rámci tenanta.
-- REF: docs/OWNER_PORTAL_SECURITY_AUDIT.md

DROP POLICY IF EXISTS "reservations_select" ON public.reservations;

CREATE POLICY "reservations_select" ON public.reservations FOR SELECT
  USING (
    public.is_super_admin()
    OR (
      EXISTS (
        SELECT 1 FROM public.apartments a
        WHERE a.id = reservations.apartment_id AND a.tenant_id = public.my_tenant_id()
      )
      AND (
        SELECT p.role FROM public.profiles p
        WHERE p.auth_id = auth.uid()
        LIMIT 1
      ) IS DISTINCT FROM 'property_owner'
    )
  );

COMMENT ON POLICY "reservations_select" ON public.reservations IS
  'Čtení rezervací: super_admin nebo tenant (kromě property_owner). Majitelé používají reservations_property_owner_select.';
