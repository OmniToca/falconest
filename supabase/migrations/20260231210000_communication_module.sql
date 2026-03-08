-- =============================================================================
-- FalcoNest – Modul Komunikace (šablony zpráv pro řidiče)
-- =============================================================================
-- Modul Komunikace umožňuje agenturám spravovat šablony WhatsApp zpráv.
-- Řidiči je používají v mobilní aplikaci pro rychlé zprávy hostům.
-- Modul je zdarma (price_eur = 0) a aktivujeme ho pro všechny existující tenanty.
-- =============================================================================

INSERT INTO public.modules (key, name, price_eur, show_in_menu, pricing_type, order_index)
VALUES ('communication', 'Komunikace', 0, true, 'fixed', 9)
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  price_eur = EXCLUDED.price_eur,
  show_in_menu = EXCLUDED.show_in_menu,
  pricing_type = EXCLUDED.pricing_type,
  order_index = EXCLUDED.order_index;

-- Dočasná SECURITY DEFINER funkce pro aktivaci modulu.
CREATE OR REPLACE FUNCTION public._activate_communication_for_all_tenants()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.tenant_modules (tenant_id, module_id, status)
  SELECT t.id, m.id, 'active'
  FROM public.tenants t
  CROSS JOIN (SELECT id FROM public.modules WHERE key = 'communication' LIMIT 1) m
  WHERE t.deleted_at IS NULL
    AND m.id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.tenant_modules tm
      WHERE tm.tenant_id = t.id
        AND tm.module_id = m.id
        AND tm.deleted_at IS NULL
    );
END;
$$;

SELECT public._activate_communication_for_all_tenants();

DROP FUNCTION IF EXISTS public._activate_communication_for_all_tenants();
