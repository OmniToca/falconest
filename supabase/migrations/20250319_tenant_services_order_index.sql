-- =============================================================================
-- FalcoNest – Řazení v katalogu služeb agentury (tenant_services)
-- =============================================================================
-- Přidá sloupec order_index pro pořadí položek v UI (stejný koncept jako u modulů).
-- =============================================================================

ALTER TABLE public.tenant_services
  ADD COLUMN IF NOT EXISTS order_index integer DEFAULT 0;

COMMENT ON COLUMN public.tenant_services.order_index IS 'Pořadí služby v katalogu (0 = první, vyšší = níže). Řazení: ORDER BY order_index ASC.';
