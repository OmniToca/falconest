-- =============================================================================
-- FalcoNest – apartment_owners.tenant_id (denormalizace pro safeFrom na klientovi)
-- =============================================================================
-- PROČ: Tabulka apartment_owners historicky neměla tenant_id; aplikace musela používat
-- holý client.from() a spoléhat jen na RLS. SupabaseService.safeFrom vždy přidává
-- .eq('tenant_id', currentTenant) – bez tohoto sloupce nelze „Frontend Firewall“ uplatnit.
-- Hodnotu bereme z apartments.tenant_id (zdroj pravdy vazby byt → agentura).
-- =============================================================================

ALTER TABLE public.apartment_owners
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES public.tenants (id);

UPDATE public.apartment_owners ao
SET tenant_id = a.tenant_id
FROM public.apartments a
WHERE a.id = ao.apartment_id
  AND ao.tenant_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_apartment_owners_tenant_id ON public.apartment_owners (tenant_id);

COMMENT ON COLUMN public.apartment_owners.tenant_id IS 'Denormalizace: shodné s apartments.tenant_id pro daný apartment_id. Nutné pro klientové dotazy přes SupabaseService.safeFrom.';

-- PROČ trigger: INSERT bez tenant_id v payloadu (legacy skripty, onboarding) stejně doplní správnou agenturu z bytu.
CREATE OR REPLACE FUNCTION public.apartment_owners_set_tenant_from_apartment ()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $$
BEGIN
  IF NEW.tenant_id IS NULL THEN
    SELECT
      a.tenant_id INTO NEW.tenant_id
    FROM
      public.apartments a
    WHERE
      a.id = NEW.apartment_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_apartment_owners_set_tenant ON public.apartment_owners;

CREATE TRIGGER trg_apartment_owners_set_tenant
  BEFORE INSERT OR UPDATE OF apartment_id ON public.apartment_owners
  FOR EACH ROW
  EXECUTE PROCEDURE public.apartment_owners_set_tenant_from_apartment ();
