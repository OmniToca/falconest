-- =============================================================================
-- FalcoNest – View "Hlídač hotovosti" (audit výběru hotovosti z úkolů)
-- =============================================================================
-- CÍL:
--  - upozornit na completed úkoly s očekávanou hotovostí, kde chybí výběr,
--  - odhalit duplicitní zápisy výběru k jednomu task_id,
--  - porovnat očekávanou částku vs. skutečně vybranou částku (po odečtení storna).
--
-- LOGIKA:
--  expected_cash = amount_to_collect + transit_amount_to_collect (z tasks.metadata)
--  collected_cash = Σ(COLLECTED_FROM_GUEST) - Σ(|CASH_COLLECTION_REVERSAL|)
-- =============================================================================

DROP VIEW IF EXISTS public.vw_cash_collection_audit;

CREATE VIEW public.vw_cash_collection_audit AS
WITH base_tasks AS (
  SELECT
    t.id AS task_id,
    t.tenant_id,
    t.apartment_id,
    (
      CASE
        WHEN coalesce(t.metadata ->> 'amount_to_collect', '') ~ '^-?[0-9]+([.][0-9]+)?$'
          THEN (t.metadata ->> 'amount_to_collect')::numeric
        ELSE 0::numeric
      END
      +
      CASE
        WHEN coalesce(t.metadata ->> 'transit_amount_to_collect', '') ~ '^-?[0-9]+([.][0-9]+)?$'
          THEN (t.metadata ->> 'transit_amount_to_collect')::numeric
        ELSE 0::numeric
      END
    ) AS expected_cash
  FROM public.tasks t
  WHERE t.status = 'completed'
    AND t.deleted_at IS NULL
),
eligible_tasks AS (
  SELECT *
  FROM base_tasks
  WHERE expected_cash > 0
),
cash_agg AS (
  SELECT
    et.task_id,
    et.tenant_id,
    count(*) FILTER (WHERE tx.transaction_type = 'COLLECTED_FROM_GUEST')::int AS collected_count,
    coalesce(sum(tx.amount) FILTER (WHERE tx.transaction_type = 'COLLECTED_FROM_GUEST'), 0::numeric) AS collected_sum,
    coalesce(sum(abs(tx.amount)) FILTER (WHERE tx.transaction_type = 'CASH_COLLECTION_REVERSAL'), 0::numeric) AS reversal_sum
  FROM eligible_tasks et
  LEFT JOIN public.employee_cash_transactions tx
    ON tx.task_id = et.task_id
   AND tx.tenant_id = et.tenant_id
   AND tx.transaction_type IN ('COLLECTED_FROM_GUEST', 'CASH_COLLECTION_REVERSAL')
  GROUP BY et.task_id, et.tenant_id
)
SELECT
  et.tenant_id,
  et.task_id,
  et.apartment_id,
  et.expected_cash,
  (coalesce(ca.collected_sum, 0::numeric) - coalesce(ca.reversal_sum, 0::numeric)) AS collected_cash,
  coalesce(ca.collected_count, 0) AS collected_count,
  CASE
    WHEN coalesce(ca.collected_count, 0) = 0 THEN 'missing_cash'
    WHEN coalesce(ca.collected_count, 0) > 1 THEN 'duplicate_cash'
    WHEN abs((coalesce(ca.collected_sum, 0::numeric) - coalesce(ca.reversal_sum, 0::numeric)) - et.expected_cash) > 0.009
      THEN 'amount_mismatch'
    ELSE 'ok'
  END AS anomaly_type
FROM eligible_tasks et
LEFT JOIN cash_agg ca
  ON ca.task_id = et.task_id
 AND ca.tenant_id = et.tenant_id;

COMMENT ON VIEW public.vw_cash_collection_audit IS
  'Audit completed úkolů s očekávanou hotovostí: missing_cash, duplicate_cash, amount_mismatch, ok.';

