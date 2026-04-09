-- =============================================================================
-- FalcoNest – Modul „Mapa“ (mapový dispečink) – registrace a aktivace pro všechny tenanty
-- =============================================================================
-- PROČ: Mapa je plnohodnotný SaaS modul v menu (IndexedStack), ne hardcoded položka.
-- order_index 45 – za plánovacím kalendářem a před moduly s nižším pořadím v DB menu.
-- Aktivace pro všechny existující tenanty přes SECURITY DEFINER (RLS na tenant_modules).
-- =============================================================================

INSERT INTO public.modules (
  key,
  name,
  description,
  price_eur,
  show_in_menu,
  pricing_type,
  order_index
)
VALUES (
  'map',
  'Mapa',
  'Interaktivní mapový dispečink',
  0,
  true,
  'fixed',
  45
)
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price_eur = EXCLUDED.price_eur,
  show_in_menu = EXCLUDED.show_in_menu,
  pricing_type = EXCLUDED.pricing_type,
  order_index = EXCLUDED.order_index;

CREATE OR REPLACE FUNCTION public._activate_map_module_for_all_tenants()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.tenant_modules (tenant_id, module_id, status)
  SELECT t.id, m.id, 'active'
  FROM public.tenants t
  CROSS JOIN (SELECT id FROM public.modules WHERE key = 'map' LIMIT 1) m
  WHERE t.deleted_at IS NULL
    AND m.id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.tenant_modules tm
      WHERE tm.tenant_id = t.id
        AND tm.module_id = m.id
        AND tm.deleted_at IS NULL
    );
END;
$$;

SELECT public._activate_map_module_for_all_tenants();

DROP FUNCTION IF EXISTS public._activate_map_module_for_all_tenants();
