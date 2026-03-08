-- =============================================================================
-- FalcoNest – Adresář klienta (Varianta A) pro partnerské agentury
-- =============================================================================
-- PROČ: Při řešení transferů k externím agenturám (client_type = 'agency') potřebujeme
-- ukládat jejich externí adresy – např. "Apartmán u moře", "Kancelář v centru".
-- Každý klient-agentura může mít více adres pro různé lokace (transfer odvoz, vyzvednutí).
--
-- Vztah: client_addresses.client_id → clients.id. Tenant izolace přes tenant_id.
-- Soft delete: deleted_at (NULL = aktivní). RLS konzistentní s clients.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka client_addresses
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.client_addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  client_id uuid NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  label text NOT NULL,
  address text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  deleted_at timestamp with time zone
);

COMMENT ON TABLE public.client_addresses IS 'Adresář adres klientů – pro externí agentury (agency) ukládání jejich lokací (transfer odvoz/vyzvednutí).';
COMMENT ON COLUMN public.client_addresses.client_id IS 'FK na clients – klient, ke kterému adresa patří.';
COMMENT ON COLUMN public.client_addresses.label IS 'Lidsky čitelný název – např. "Apartmán u moře", "Kancelář v centru".';
COMMENT ON COLUMN public.client_addresses.address IS 'Plná adresa pro řidiče – ulice, město, GPS, instrukce.';
COMMENT ON COLUMN public.client_addresses.deleted_at IS 'Soft delete; NULL = aktivní záznam.';

-- Indexy pro RLS a časté dotazy
CREATE INDEX IF NOT EXISTS idx_client_addresses_tenant_id ON public.client_addresses(tenant_id);
CREATE INDEX IF NOT EXISTS idx_client_addresses_client_id ON public.client_addresses(client_id);
CREATE INDEX IF NOT EXISTS idx_client_addresses_deleted_at ON public.client_addresses(deleted_at) WHERE deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- 2. RLS politiky – tenant izolace (konzistence s clients)
-- -----------------------------------------------------------------------------
ALTER TABLE public.client_addresses ENABLE ROW LEVEL SECURITY;

-- SELECT: Uživatel vidí pouze adresy svého tenanta
CREATE POLICY "client_addresses_select"
  ON public.client_addresses FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

-- INSERT: Uživatel smí vkládat pouze adresy svého tenanta
CREATE POLICY "client_addresses_insert"
  ON public.client_addresses FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

-- UPDATE: Uživatel smí upravovat pouze adresy svého tenanta
CREATE POLICY "client_addresses_update"
  ON public.client_addresses FOR UPDATE
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );

-- DELETE: Uživatel smí mazat pouze adresy svého tenanta
CREATE POLICY "client_addresses_delete"
  ON public.client_addresses FOR DELETE
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  );
