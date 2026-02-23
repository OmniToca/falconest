-- =============================================================================
-- FalcoNest – Modul Finance a Zaměstnanecká pokladna (Cash Accountability)
-- =============================================================================
-- 1. Registrace modulů finance (hlavní, zdarma) a finance_export (placený sub-modul).
-- 2. Tabulky employee_cash_wallets a employee_cash_transactions pro evidenci hotovosti
--    vybrané od hostů a předané agentuře.
-- POZNÁMKA: tenant_wallets a wallet_transactions jsou nesouvisející systém kreditů.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Registrace modulů v tabulce modules
-- -----------------------------------------------------------------------------
INSERT INTO public.modules (key, name, price_eur, show_in_menu, pricing_type, order_index)
VALUES ('finance', 'Finance a Hotovost', 0, true, 'fixed', 7)
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  price_eur = EXCLUDED.price_eur,
  show_in_menu = EXCLUDED.show_in_menu,
  pricing_type = EXCLUDED.pricing_type;

INSERT INTO public.modules (key, name, parent_module_key, show_in_menu, price_eur, pricing_type)
VALUES ('finance_export', 'Podklady pro fakturaci', 'finance', false, 29, 'fixed')
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  parent_module_key = EXCLUDED.parent_module_key,
  show_in_menu = EXCLUDED.show_in_menu,
  price_eur = EXCLUDED.price_eur,
  pricing_type = EXCLUDED.pricing_type;

-- -----------------------------------------------------------------------------
-- 2. Tabulka employee_cash_wallets (Kapsa zaměstnance)
-- -----------------------------------------------------------------------------
-- Jeden řádek na (tenant_id, profile_id). Drží aktuální dlužnou hotovost u zaměstnance.
-- balance > 0 = zaměstnanec má u sebe peníze (od hostů), balance = 0 = vyrovnáno.
CREATE TABLE public.employee_cash_wallets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  balance numeric NOT NULL DEFAULT 0,
  updated_at timestamptz DEFAULT now(),
  UNIQUE (tenant_id, profile_id)
);

COMMENT ON TABLE public.employee_cash_wallets IS 'Zaměstnanecká pokladna – kapsa zaměstnance s dlužnou hotovostí vybranou od hostů.';
COMMENT ON COLUMN public.employee_cash_wallets.balance IS 'Aktuální dlužná hotovost u zaměstnance (kladná = má u sebe peníze).';

CREATE INDEX idx_employee_cash_wallets_tenant ON public.employee_cash_wallets(tenant_id);
CREATE INDEX idx_employee_cash_wallets_profile ON public.employee_cash_wallets(profile_id);

-- -----------------------------------------------------------------------------
-- 3. Tabulka employee_cash_transactions (Účetní kniha výběrů)
-- -----------------------------------------------------------------------------
-- Append-only záznamy: výběr od hosta (COLLECTED_FROM_GUEST) nebo odevzdání agentuře (HANDED_TO_AGENCY).
-- amount kladné = výběr (zvyšuje balance), záporné = odevzdání (snižuje balance).
CREATE TABLE public.employee_cash_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  wallet_id uuid NOT NULL REFERENCES public.employee_cash_wallets(id) ON DELETE CASCADE,
  task_id uuid REFERENCES public.tasks(id) ON DELETE SET NULL,
  amount numeric NOT NULL,
  transaction_type text NOT NULL CHECK (transaction_type IN ('COLLECTED_FROM_GUEST', 'HANDED_TO_AGENCY')),
  created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.employee_cash_transactions IS 'Účetní kniha výběrů – evidence hotovosti vybrané od hostů a předané agentuře.';
COMMENT ON COLUMN public.employee_cash_transactions.transaction_type IS 'COLLECTED_FROM_GUEST = výběr od hosta (Check-in, Transfer); HANDED_TO_AGENCY = odevzdání agentuře.';

CREATE INDEX idx_employee_cash_transactions_wallet ON public.employee_cash_transactions(wallet_id);
CREATE INDEX idx_employee_cash_transactions_tenant ON public.employee_cash_transactions(tenant_id);
CREATE INDEX idx_employee_cash_transactions_task ON public.employee_cash_transactions(task_id);

-- -----------------------------------------------------------------------------
-- 4. Row Level Security (RLS) – employee_cash_wallets
-- -----------------------------------------------------------------------------
ALTER TABLE public.employee_cash_wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "employee_cash_wallets_select"
  ON public.employee_cash_wallets FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "employee_cash_wallets_insert"
  ON public.employee_cash_wallets FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "employee_cash_wallets_update"
  ON public.employee_cash_wallets FOR UPDATE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

-- -----------------------------------------------------------------------------
-- 5. Row Level Security (RLS) – employee_cash_transactions
-- -----------------------------------------------------------------------------
ALTER TABLE public.employee_cash_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "employee_cash_transactions_select"
  ON public.employee_cash_transactions FOR SELECT
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "employee_cash_transactions_insert"
  ON public.employee_cash_transactions FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );

CREATE POLICY "employee_cash_transactions_update"
  ON public.employee_cash_transactions FOR UPDATE
  USING (
    public.is_super_admin()
    OR tenant_id = (SELECT tenant_id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
  );
