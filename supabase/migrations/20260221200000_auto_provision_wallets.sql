-- =============================================================================
-- FalcoNest – Automatický provisioning peněženek pro tenanty
-- =============================================================================
-- Každý nově vytvořený tenant automaticky dostane řádek v tenant_wallets
-- s nulovým zůstatkem (AFTER INSERT trigger na tabulce tenants).
-- Migrace zároveň provádí zpětné doplnění (backfill) – vytvoří peněženky
-- pro stávající testovací tenanty, kteří je dosud nemají (ON CONFLICT DO NOTHING).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Spouštěcí funkce – při vložení nového tenanta založí peněženku
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_tenant_wallet()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Bezpečný INSERT: při každém novém tenantu založíme peněženku s nulovým zůstatkem.
  -- IGNORE duplicity: pokud by řádek už existoval (nestandardní stav), INSERT selže
  -- na PK – pro jistotu použijeme ON CONFLICT v samotném INSERT.
  INSERT INTO public.tenant_wallets (tenant_id, balance)
  VALUES (NEW.id, 0)
  ON CONFLICT (tenant_id) DO NOTHING;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_tenant_wallet() IS
  'Trigger funkce – při vložení nového tenanta automaticky založí řádek v tenant_wallets s balance = 0. Ochrana proti duplicitám přes ON CONFLICT.';

-- -----------------------------------------------------------------------------
-- 2. Trigger na tabulce tenants – spouští se po každém INSERT
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_tenant_wallet_after_insert ON public.tenants;

CREATE TRIGGER trg_tenant_wallet_after_insert
  AFTER INSERT ON public.tenants
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_tenant_wallet();

COMMENT ON TRIGGER trg_tenant_wallet_after_insert ON public.tenants IS
  'Po vložení nového tenanta automaticky založí peněženku (tenant_wallets) s nulovým zůstatkem.';

-- -----------------------------------------------------------------------------
-- 3. Zpětné doplnění (Backfill) – peněženky pro stávající tenanty
-- -----------------------------------------------------------------------------
-- Stávající agentury (testovací tenanty) dostanou peněženku okamžitě.
-- ON CONFLICT (tenant_id) DO NOTHING: pokud tenant peněženku už má (např. ručně
-- založenou před migrací), nic neděláme – žádný duplicate key error.
INSERT INTO public.tenant_wallets (tenant_id, balance)
SELECT id, 0
FROM public.tenants
ON CONFLICT (tenant_id) DO NOTHING;
