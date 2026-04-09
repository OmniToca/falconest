-- =============================================================================
-- FalcoNest – Fronta: ruční (ad-hoc) zprávy bez automation_rules
-- =============================================================================
-- PROČ: Manažer může vložit testovací zprávu s rule_id = NULL a entity_type = adhoc.
-- Existující řádky mají rule_id NOT NULL – měníme jen nové možnosti + RLS.
-- =============================================================================

ALTER TABLE public.automation_message_queue
  DROP CONSTRAINT IF EXISTS automation_message_queue_entity_type_check;

ALTER TABLE public.automation_message_queue
  ADD CONSTRAINT automation_message_queue_entity_type_check
  CHECK (entity_type IN ('reservation', 'task', 'adhoc'));

COMMENT ON COLUMN public.automation_message_queue.entity_type IS
  'reservation | task | adhoc (ruční zpráva z admin UI, bez pravidla).';

ALTER TABLE public.automation_message_queue
  ALTER COLUMN rule_id DROP NOT NULL;

-- INSERT: buď platné pravidlo stejného tenanta, nebo ad-hoc (bez rule_id).
DROP POLICY IF EXISTS automation_message_queue_insert_tenant ON public.automation_message_queue;
CREATE POLICY automation_message_queue_insert_tenant
  ON public.automation_message_queue
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND (
        EXISTS (
          SELECT 1
          FROM public.automation_rules r
          WHERE r.id = rule_id
            AND r.tenant_id = public.my_tenant_id()
        )
        OR (
          rule_id IS NULL
          AND entity_type = 'adhoc'
        )
      )
    )
  );

-- UPDATE: řádek musí zůstat vázaný na tenanta; ad-hoc řádky nemají rule_id.
DROP POLICY IF EXISTS automation_message_queue_update_tenant ON public.automation_message_queue;
CREATE POLICY automation_message_queue_update_tenant
  ON public.automation_message_queue
  FOR UPDATE
  TO authenticated
  USING (
    public.is_super_admin()
    OR tenant_id = public.my_tenant_id()
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND (
        (
          rule_id IS NULL
          AND entity_type = 'adhoc'
        )
        OR EXISTS (
          SELECT 1
          FROM public.automation_rules r
          WHERE r.id = rule_id
            AND r.tenant_id = public.my_tenant_id()
        )
      )
    )
  );
