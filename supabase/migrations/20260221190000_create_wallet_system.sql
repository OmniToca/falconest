-- =============================================================================
-- FalcoNest – Prepaid Wallet (Předplacená peněženka) pro prémiové automatizační moduly
-- =============================================================================
-- Klienti si kupují balíčky kreditů; každé použití (např. generování úkolů)
-- strhne kredity. Tabulka tenant_wallets drží aktuální stav, wallet_transactions
-- je append-only účetní kniha. Strhávání probíhá VÝHRADNĚ přes RPC funkci
-- deduct_wallet_credits s řádkovým zámkem (FOR UPDATE) – ochrana proti Race Condition
-- při souběžném generování úkolů více dispečery.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Tabulka tenant_wallets – jeden řádek na tenanta, aktuální stav kreditů
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tenant_wallets (
  tenant_id uuid NOT NULL PRIMARY KEY REFERENCES public.tenants(id) ON DELETE CASCADE,
  balance integer NOT NULL DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.tenant_wallets IS 'Předplacená peněženka – aktuální počet kreditů na tenanta. Strhávání VÝHRADNĚ přes RPC deduct_wallet_credits (ochrana Race Condition).';
COMMENT ON COLUMN public.tenant_wallets.balance IS 'Aktuální stav kreditů. Kladné = dostupný zůstatek.';
COMMENT ON COLUMN public.tenant_wallets.updated_at IS 'Čas poslední změny zůstatku.';

CREATE INDEX IF NOT EXISTS idx_tenant_wallets_tenant_id ON public.tenant_wallets(tenant_id);

-- -----------------------------------------------------------------------------
-- 2. Tabulka wallet_transactions – účetní kniha (append only)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  amount integer NOT NULL,
  transaction_type text NOT NULL,
  reference_id text,
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.wallet_transactions IS 'Účetní kniha transakcí – append only. Kladné amount = dobití (TOP_UP), záporné = útrata (USAGE_*).';
COMMENT ON COLUMN public.wallet_transactions.amount IS 'Kladné = dobití, záporné = stržení kreditů.';
COMMENT ON COLUMN public.wallet_transactions.transaction_type IS 'Např. TOP_UP (dobití), USAGE_AUTO_TASKS (generování úkolů).';
COMMENT ON COLUMN public.wallet_transactions.reference_id IS 'Volitelná vazba na Stripe payment ID, ID logu generování atd.';

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_tenant_id ON public.wallet_transactions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON public.wallet_transactions(created_at);

-- -----------------------------------------------------------------------------
-- 3. RLS na tenant_wallets – admin/manager POUZE ČTE, super_admin vše
-- -----------------------------------------------------------------------------
-- ZÁKAZ přímé úpravy z klienta! Jakékoli strhávání jde přes RPC funkci.
ALTER TABLE public.tenant_wallets ENABLE ROW LEVEL SECURITY;

-- Super Admin (nebo service_role) má plná práva – pro dobití kreditů, nastavení.
CREATE POLICY "tenant_wallets_super_admin_full"
  ON public.tenant_wallets
  FOR ALL
  TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- Admin a manager smí POUZE ČÍST vlastní peněženku (pro zobrazení zůstatku v UI).
-- Žádný INSERT ani UPDATE – strhávání probíhá přes RPC.
CREATE POLICY "tenant_wallets_select_own_tenant"
  ON public.tenant_wallets
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

-- -----------------------------------------------------------------------------
-- 4. RLS na wallet_transactions – admin/manager POUZE ČTE, super_admin vše
-- -----------------------------------------------------------------------------
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wallet_transactions_super_admin_full"
  ON public.wallet_transactions
  FOR ALL
  TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

CREATE POLICY "wallet_transactions_select_own_tenant"
  ON public.wallet_transactions
  FOR SELECT
  TO authenticated
  USING (
    tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

-- -----------------------------------------------------------------------------
-- 5. RPC deduct_wallet_credits – stržení kreditů s transakčním zámkem
-- -----------------------------------------------------------------------------
-- PROČ RPC: Klient nesmí přímo UPDATE tenant_wallets (bezpečnost). Veškeré
-- strhávání musí jít touto funkcí, která drží zámek řádku (FOR UPDATE) –
-- zabrání Race Condition (dva dispečeři současně generují úkoly, oba by strhli
-- ze stejného zůstatku bez zámku).
CREATE OR REPLACE FUNCTION public.deduct_wallet_credits(
  p_tenant_id uuid,
  p_deduct_amount integer,
  p_transaction_type text,
  p_reference_id text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_balance integer;
  v_caller_tenant_id uuid;
BEGIN
  -- Autorizace: volající smí strhávat pouze pro svůj tenant (admin/manager) nebo být super_admin.
  v_caller_tenant_id := (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1);
  IF v_caller_tenant_id IS NULL AND NOT public.is_super_admin() THEN
    RETURN FALSE;  -- Nepřihlášený nebo bez tenanta.
  END IF;
  IF NOT public.is_super_admin() AND v_caller_tenant_id IS DISTINCT FROM p_tenant_id THEN
    RETURN FALSE;  -- Nemůže strhávat kredity jiného tenanta.
  END IF;

  -- Validace: částka musí být kladná (strháváme kladné číslo)
  IF p_deduct_amount <= 0 THEN
    RAISE EXCEPTION 'deduct_wallet_credits: p_deduct_amount musí být kladné, bylo %', p_deduct_amount;
  END IF;

  -- Zámek řádku: FOR UPDATE blokuje ostatní transakce čekající na stejný řádek.
  -- Ochrana proti Race Condition – souběžné volání z více dispečerů.
  SELECT balance INTO v_current_balance
  FROM public.tenant_wallets
  WHERE tenant_id = p_tenant_id
  FOR UPDATE;

  -- Řádek neexistuje (tenant ještě nemá peněženku) – nelze strhnout.
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- Nedostatek kreditů – neprovádíme žádnou změnu, vracíme FALSE.
  IF v_current_balance < p_deduct_amount THEN
    RETURN FALSE;
  END IF;

  -- Provedení stržení: UPDATE zůstatku + INSERT do účetní knihy (atomicky v rámci transakce).
  UPDATE public.tenant_wallets
  SET
    balance = balance - p_deduct_amount,
    updated_at = now()
  WHERE tenant_id = p_tenant_id;

  INSERT INTO public.wallet_transactions (tenant_id, amount, transaction_type, reference_id)
  VALUES (p_tenant_id, -p_deduct_amount, p_transaction_type, p_reference_id);

  RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION public.deduct_wallet_credits(uuid, integer, text, text) IS
  'Strhne kredity z peněženky tenanta. Používá FOR UPDATE pro ochranu proti Race Condition. Vrací TRUE při úspěchu, FALSE při nedostatečném zůstatku nebo chybějící peněžence.';

-- Povolení volání RPC pro přihlášené uživatele (admin/manager/super_admin).
-- Autorizace tenant_id probíhá uvnitř funkce.
GRANT EXECUTE ON FUNCTION public.deduct_wallet_credits(uuid, integer, text, text) TO authenticated;
