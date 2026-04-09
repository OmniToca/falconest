-- =============================================================================
-- FalcoNest – Rozšíření trigger_context u šablon zpráv na všechny kategorie úkolů
-- =============================================================================
-- trigger_context už je typ TEXT bez CHECK – přijímá libovolný řetězec.
-- Aktualizujeme pouze komentář: hodnoty odpovídají sloupci code z task_categories
-- (cleaning, maintenance, check_in, transfer_in, …), aby agentury mohly vázat
-- šablony na libovolný typ úkolu, ne jen na transfer/check_in/check_out.
-- =============================================================================

COMMENT ON COLUMN public.tenant_message_templates.trigger_context IS
  'Volitelně: kód kategorie úkolu z task_categories (např. cleaning, maintenance, check_in, transfer_in). NULL = obecná šablona bez vazby na typ úkolu. Filtrování v UI řidiče a v seznamu šablon.';
