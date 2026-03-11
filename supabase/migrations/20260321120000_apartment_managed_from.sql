-- Začátek správy (managed_from) u apartmánů – první den měsíce, od kterého se účtuje měsíční paušál.
-- Zamezí retroaktivnímu účtování v Reportech a Podkladech pro fakturaci.
ALTER TABLE apartments
  ADD COLUMN IF NOT EXISTS managed_from DATE;

COMMENT ON COLUMN apartments.managed_from IS 'První den měsíce, od kterého se účtuje měsíční paušál (monthly_management_fee). Null = započítat vždy (zpětná kompatibilita).';
