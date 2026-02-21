-- =============================================================================
-- FalcoNest – Přidání sloupce name do task_categories (Multi-tenant B2B SaaS)
-- =============================================================================
-- Sloupec name = zobrazovaný název pro uživatele (např. 'Check-in', 'Úklid').
-- =============================================================================

ALTER TABLE public.task_categories
  ADD COLUMN IF NOT EXISTS name text NOT NULL DEFAULT '';

-- Aktualizace existujících záznamů – name z code (fallback pro stará data)
UPDATE public.task_categories
SET name = INITCAP(REPLACE(code, '_', ' '))
WHERE name = '' OR name IS NULL;

-- =============================================================================
-- SEED – výchozí kategorie (zakomentováno, odkomentuj a nahraď :tenant_id)
-- =============================================================================
/*
INSERT INTO public.task_categories (tenant_id, code, name, color_hex, icon_name, order_index) VALUES
  (:tenant_id, 'cleaning',     'Úklid',            '#F3E5F5', 'cleaning_services', 0),
  (:tenant_id, 'transfer_in',  'Transfer příjezd', '#E3F2FD', 'directions_car', 1),
  (:tenant_id, 'transfer_out', 'Transfer odjezd',  '#E3F2FD', 'directions_car', 2),
  (:tenant_id, 'check_in',     'Check-in',         '#FFF3E0', 'key', 3),
  (:tenant_id, 'check_out',    'Check-out',        '#FFF3E0', 'key', 4),
  (:tenant_id, 'maintenance',  'Údržba',           '#FFEBEE', 'warning_amber_rounded', 5)
ON CONFLICT (tenant_id, code) DO UPDATE SET
  name = EXCLUDED.name,
  color_hex = EXCLUDED.color_hex,
  icon_name = EXCLUDED.icon_name,
  order_index = EXCLUDED.order_index;
*/
