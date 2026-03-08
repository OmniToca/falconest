-- =============================================================================
-- FalcoNest – Sub-modul Vyúčtování a Provize (Settlements)
-- =============================================================================
-- Registrace modulu settlements jako sub-modulu finance (záložka v UI, ne položka menu).
-- Používá se pro prémiové zamčení záložky „Vyúčtování“ v Finance dashboardu.
-- =============================================================================

INSERT INTO public.modules (key, name, parent_module_key, description, show_in_menu, price_eur, pricing_type)
VALUES (
  'settlements',
  'Vyúčtování a Provize',
  'finance',
  'Detailní rozpad zisku z úkolů, výplaty zaměstnancům a provize partnerům.',
  false,
  15.00,
  'fixed'
)
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  parent_module_key = EXCLUDED.parent_module_key,
  description = EXCLUDED.description,
  show_in_menu = EXCLUDED.show_in_menu,
  price_eur = EXCLUDED.price_eur,
  pricing_type = EXCLUDED.pricing_type;
