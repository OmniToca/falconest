-- =============================================================================
-- FalcoNest – fakturační údaje a cena za byt u tenanta (pro CRM / Tenant Detail)
-- =============================================================================
-- billing_info = jsonb pro adresu a IČO/DIČ; price_per_apartment = měsíční základ za byt.
-- =============================================================================

ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS billing_info jsonb DEFAULT '{}';

ALTER TABLE public.tenants
  ADD COLUMN IF NOT EXISTS price_per_apartment numeric(10,2);

COMMENT ON COLUMN public.tenants.billing_info IS 'Fakturační údaje: company_name, ico, dic, street, city, zip, country, contact_email, phone.';
COMMENT ON COLUMN public.tenants.price_per_apartment IS 'Měsíční cena za jeden byt (základ předplatného) v CZK.';
