-- =============================================================================
-- FalcoNest – majitel smí založit řádek apartment_investment_metrics u svého bytu
-- =============================================================================
-- PROČ: Předchozí RLS povolovala majiteli jen SELECT/UPDATE. Bez INSERT nešlo první
-- uložení metrik z Klientského portálu (upsert selže na větvi INSERT). Politika
-- vyžaduje zapnuté [apartments.investment_tracking_enabled], aby se tabulka neplnila u bytů bez modulu.
-- =============================================================================

DROP POLICY IF EXISTS "apartment_investment_metrics_property_owner_insert" ON public.apartment_investment_metrics;

CREATE POLICY "apartment_investment_metrics_property_owner_insert"
  ON public.apartment_investment_metrics
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1 FROM public.apartment_owners ao
      WHERE ao.apartment_id = apartment_investment_metrics.apartment_id
        AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
        AND ao.deleted_at IS NULL
    )
    AND EXISTS (
      SELECT 1 FROM public.apartments a
      WHERE a.id = apartment_investment_metrics.apartment_id
        AND a.investment_tracking_enabled IS TRUE
        AND a.deleted_at IS NULL
    )
  );

COMMENT ON POLICY "apartment_investment_metrics_property_owner_insert" ON public.apartment_investment_metrics IS
  'INSERT: property_owner jen pro vlastní byt s investment_tracking_enabled = true.';

NOTIFY pgrst, 'reload schema';
