-- Přidání sloupce expected_amount do employee_cash_transactions.
--
-- PROČ: Umožňuje počítat spropitné (rozdíl amount vs expected_amount při výběru od hosta).
-- expected_amount = očekávaná částka z metadata.amount_to_collect úkolu.
-- amount > expected_amount => spropitné (zeleně), amount < expected_amount => nedoplatek (červeně).
ALTER TABLE public.employee_cash_transactions
  ADD COLUMN IF NOT EXISTS expected_amount numeric(10,2);
