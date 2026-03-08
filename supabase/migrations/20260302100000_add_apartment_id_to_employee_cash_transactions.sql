-- Přidání sloupce apartment_id do employee_cash_transactions.
-- PROČ: Firemní výdaje (materiál do bytu) musí být navázány na apartmán,
-- aby se při měsíční faktuře majitele mohly náklady automaticky strhnout.
-- Staré transakce mají apartment_id = NULL – zpětná kompatibilita zachována.

ALTER TABLE public.employee_cash_transactions
  ADD COLUMN IF NOT EXISTS apartment_id uuid REFERENCES public.apartments(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.employee_cash_transactions.apartment_id IS 'Vazba na apartmán pro firemní výdaje – stržení nákladů ve faktuře majitele.';
