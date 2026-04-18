-- -----------------------------------------------------------------------------
-- RLS: Majitel (property_owner) smí číst checklisty a položky u úkolů u svých bytů.
-- PROČ: Klientský portál zobrazuje fotodokumentaci z task_checklist_items.photo_url;
-- bez této politiky by SELECT selhal (původně jen admin/manager + přiřazený worker).
-- ADITIVNÍ: nové politiky, stávající zůstávají (OR přes PostgreSQL).
-- -----------------------------------------------------------------------------

CREATE POLICY "task_checklists_select_property_owner"
  ON public.task_checklists
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1
      FROM public.tasks t
      INNER JOIN public.apartment_owners ao
        ON ao.apartment_id = t.apartment_id
        AND ao.deleted_at IS NULL
      WHERE t.id = task_checklists.task_id
        AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
    )
  );

COMMENT ON POLICY "task_checklists_select_property_owner" ON public.task_checklists IS
  'SELECT: property_owner vidí checklist jen u úkolu na vlastněném apartmánu (apartment_owners).';

CREATE POLICY "task_checklist_items_select_property_owner"
  ON public.task_checklist_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.auth_id = auth.uid() AND p.role = 'property_owner'
    )
    AND EXISTS (
      SELECT 1
      FROM public.task_checklists tc
      INNER JOIN public.tasks t ON t.id = tc.task_id
      INNER JOIN public.apartment_owners ao
        ON ao.apartment_id = t.apartment_id
        AND ao.deleted_at IS NULL
      WHERE tc.id = task_checklist_items.task_checklist_id
        AND ao.owner_id IN (SELECT id FROM public.profiles WHERE auth_id = auth.uid())
    )
  );

COMMENT ON POLICY "task_checklist_items_select_property_owner" ON public.task_checklist_items IS
  'SELECT: property_owner vidí položky checklistu včetně photo_url u úkolů na vlastněných bytech.';
