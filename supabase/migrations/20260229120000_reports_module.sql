-- =============================================================================
-- FalcoNest – Modul Reporty / Analytika (Phase 1 – Infrastruktura)
-- =============================================================================
-- Prémiový modul pro analytiku a grafy. Zobrazuje se v Nastavení (Fakturace/Služby)
-- a v levém menu POUZE pokud má tenant modul aktivní.
-- =============================================================================

INSERT INTO public.modules (key, name, price_eur, show_in_menu, pricing_type, order_index)
VALUES ('reports', 'Reporty', 19, true, 'fixed', 10)
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  price_eur = EXCLUDED.price_eur,
  show_in_menu = EXCLUDED.show_in_menu,
  pricing_type = EXCLUDED.pricing_type,
  order_index = EXCLUDED.order_index;
