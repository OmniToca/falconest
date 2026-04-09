-- =============================================================================
-- FalcoNest – RLS: fronta automation_message_queue pro řádky bez pravidla + task
-- =============================================================================
-- Trigger enqueue_internal_push_on_new_task_assignment vkládá rule_id NULL,
-- entity_type = 'task'. Původní politika povolovala rule_id NULL jen u 'adhoc'.
-- Rozšíření: entity_type IN ('adhoc', 'task') pro INSERT i UPDATE WITH CHECK.
-- =============================================================================

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
          AND entity_type IN ('adhoc', 'task')
        )
      )
    )
  );

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
          AND entity_type IN ('adhoc', 'task')
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

COMMENT ON POLICY automation_message_queue_insert_tenant ON public.automation_message_queue IS
  'INSERT: tenant + buď řádek s rule_id z automation_rules, nebo rule_id NULL a entity adhoc|task (systémová fronta / ad-hoc test).';

COMMENT ON POLICY automation_message_queue_update_tenant ON public.automation_message_queue IS
  'UPDATE: tenant; WITH CHECK stejná logika jako INSERT pro rule_id / entity_type.';
