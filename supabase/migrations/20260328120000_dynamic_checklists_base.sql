-- =============================================================================
-- FalcoNest – Dynamic Checklists Engine (Fáze 1): tabulky + RLS + triggery updated_at
-- =============================================================================
-- PROČ: Šablony checklistů v adminu; při vzniku úkolu se položky zkopírují do
-- task_checklist_items (neměnná historie). Worker odškrtává instance v mobilu.
-- Multi-tenant: každá tabulka má tenant_id; RLS odděluje agentury a worker vidí jen
-- řádky u úkolů, ke kterým je přiřazen (tasks.assigned_to / assigned_user_ids).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Pomocné funkce pro RLS (SECURITY DEFINER – čtení tasks bez kolize s politikami)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_tenant_admin_or_manager()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.auth_id = auth.uid()
      AND p.role IN ('admin', 'manager')
  );
$$;

COMMENT ON FUNCTION public.is_tenant_admin_or_manager() IS
  'true, pokud má přihlášený uživatel v profiles roli admin nebo manager (pro RLS checklist šablon).';

-- PROČ: Worker nemá vidět celý tenant – jen úkoly, kde je assigned_to = jeho profiles.id
-- nebo je v assigned_user_ids (stejná logika jako WorkerSyncService na klientu).
CREATE OR REPLACE FUNCTION public.is_worker_assigned_to_task(p_task_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.tasks t
    WHERE t.id = p_task_id
      AND t.deleted_at IS NULL
      AND (
        t.assigned_to = (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1)
        OR (
          t.assigned_user_ids IS NOT NULL
          AND (SELECT id FROM public.profiles WHERE auth_id = auth.uid() LIMIT 1) = ANY (t.assigned_user_ids)
        )
      )
  );
$$;

COMMENT ON FUNCTION public.is_worker_assigned_to_task(uuid) IS
  'true, pokud je aktuální uživatel (profiles přes auth_id) přiřazen k danému úkolu.';

-- -----------------------------------------------------------------------------
-- Sdílený trigger: updated_at (UTC) – stejný princip jako set_tasks_updated_at()
-- PROČ: Drift offline sync potřebuje spolehlivý serverový timestamp při každém UPDATE.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_dynamic_checklist_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := (now() AT TIME ZONE 'utc');
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.set_dynamic_checklist_updated_at() IS
  'Nastaví updated_at na UTC now u tabulek dynamických checklistů (konzistence s tasks).';

-- -----------------------------------------------------------------------------
-- 1) checklist_templates
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.checklist_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

COMMENT ON TABLE public.checklist_templates IS
  'Šablona checklistu definovaná v administraci agentury (název, aktivita).';
COMMENT ON COLUMN public.checklist_templates.is_active IS
  'false = šablona se nezobrazuje při výběru pro nové úkoly; existující instance se nemění.';

CREATE INDEX IF NOT EXISTS idx_checklist_templates_tenant_id ON public.checklist_templates(tenant_id);

DROP TRIGGER IF EXISTS checklist_templates_updated_at_trigger ON public.checklist_templates;
CREATE TRIGGER checklist_templates_updated_at_trigger
  BEFORE UPDATE ON public.checklist_templates
  FOR EACH ROW
  EXECUTE FUNCTION public.set_dynamic_checklist_updated_at();

ALTER TABLE public.checklist_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "checklist_templates_select"
  ON public.checklist_templates FOR SELECT
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

CREATE POLICY "checklist_templates_insert"
  ON public.checklist_templates FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

CREATE POLICY "checklist_templates_update"
  ON public.checklist_templates FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

CREATE POLICY "checklist_templates_delete"
  ON public.checklist_templates FOR DELETE
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

-- -----------------------------------------------------------------------------
-- 2) checklist_template_items
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.checklist_template_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  template_id uuid NOT NULL REFERENCES public.checklist_templates(id) ON DELETE CASCADE,
  title text NOT NULL,
  is_photo_required boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

COMMENT ON TABLE public.checklist_template_items IS
  'Položky šablony – pořadí a povinná fotka; při vytvoření úkolu se zkopírují do task_checklist_items.';
COMMENT ON COLUMN public.checklist_template_items.sort_order IS
  'Řazení v UI (nižší číslo = výš v seznamu).';

CREATE INDEX IF NOT EXISTS idx_checklist_template_items_template_id ON public.checklist_template_items(template_id);
CREATE INDEX IF NOT EXISTS idx_checklist_template_items_tenant_id ON public.checklist_template_items(tenant_id);

DROP TRIGGER IF EXISTS checklist_template_items_updated_at_trigger ON public.checklist_template_items;
CREATE TRIGGER checklist_template_items_updated_at_trigger
  BEFORE UPDATE ON public.checklist_template_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_dynamic_checklist_updated_at();

ALTER TABLE public.checklist_template_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "checklist_template_items_select"
  ON public.checklist_template_items FOR SELECT
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

CREATE POLICY "checklist_template_items_insert"
  ON public.checklist_template_items FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

CREATE POLICY "checklist_template_items_update"
  ON public.checklist_template_items FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

CREATE POLICY "checklist_template_items_delete"
  ON public.checklist_template_items FOR DELETE
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

-- -----------------------------------------------------------------------------
-- 3) task_checklists (jedna instance na úkol)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.task_checklists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  template_id uuid REFERENCES public.checklist_templates(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  CONSTRAINT task_checklists_task_id_unique UNIQUE (task_id)
);

COMMENT ON TABLE public.task_checklists IS
  'Instance checklistu připnutá k úkolu; template_id je jen informace o původu šablony.';
COMMENT ON COLUMN public.task_checklists.template_id IS
  'Volitelná vazba na šablonu; při smazání šablony zůstane NULL (instance řádků už je zkopírovaná).';

CREATE INDEX IF NOT EXISTS idx_task_checklists_tenant_id ON public.task_checklists(tenant_id);
CREATE INDEX IF NOT EXISTS idx_task_checklists_task_id ON public.task_checklists(task_id);
CREATE INDEX IF NOT EXISTS idx_task_checklists_template_id ON public.task_checklists(template_id);

DROP TRIGGER IF EXISTS task_checklists_updated_at_trigger ON public.task_checklists;
CREATE TRIGGER task_checklists_updated_at_trigger
  BEFORE UPDATE ON public.task_checklists
  FOR EACH ROW
  EXECUTE FUNCTION public.set_dynamic_checklist_updated_at();

ALTER TABLE public.task_checklists ENABLE ROW LEVEL SECURITY;

CREATE POLICY "task_checklists_select"
  ON public.task_checklists FOR SELECT
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_worker_assigned_to_task(task_id)
    )
  );

CREATE POLICY "task_checklists_insert"
  ON public.task_checklists FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

CREATE POLICY "task_checklists_update"
  ON public.task_checklists FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

CREATE POLICY "task_checklists_delete"
  ON public.task_checklists FOR DELETE
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

-- -----------------------------------------------------------------------------
-- 4) task_checklist_items (odškrtávané body u instance)
-- -----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.task_checklist_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  task_checklist_id uuid NOT NULL REFERENCES public.task_checklists(id) ON DELETE CASCADE,
  title text NOT NULL,
  is_photo_required boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL,
  is_completed boolean NOT NULL DEFAULT false,
  completed_at timestamptz,
  completed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  photo_url text,
  created_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
  updated_at timestamptz NOT NULL DEFAULT (now() AT TIME ZONE 'utc')
);

COMMENT ON TABLE public.task_checklist_items IS
  'Zkopírované položky z šablony v okamžiku vytvoření úkolu – worker mění stav a foto.';
COMMENT ON COLUMN public.task_checklist_items.completed_by IS
  'profiles.id pracovníka, který položku dokončil (ne auth.users – konzistence s FalcoNest).';
COMMENT ON COLUMN public.task_checklist_items.photo_url IS
  'Veřejná URL z Storage po nahrání fotky k položce.';

CREATE INDEX IF NOT EXISTS idx_task_checklist_items_task_checklist_id ON public.task_checklist_items(task_checklist_id);
CREATE INDEX IF NOT EXISTS idx_task_checklist_items_tenant_id ON public.task_checklist_items(tenant_id);

DROP TRIGGER IF EXISTS task_checklist_items_updated_at_trigger ON public.task_checklist_items;
CREATE TRIGGER task_checklist_items_updated_at_trigger
  BEFORE UPDATE ON public.task_checklist_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_dynamic_checklist_updated_at();

ALTER TABLE public.task_checklist_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "task_checklist_items_select"
  ON public.task_checklist_items FOR SELECT
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_worker_assigned_to_task(
        (SELECT tc.task_id FROM public.task_checklists tc WHERE tc.id = task_checklist_items.task_checklist_id)
      )
    )
  );

CREATE POLICY "task_checklist_items_insert"
  ON public.task_checklist_items FOR INSERT
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

CREATE POLICY "task_checklist_items_update"
  ON public.task_checklist_items FOR UPDATE
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_worker_assigned_to_task(
        (SELECT tc.task_id FROM public.task_checklists tc WHERE tc.id = task_checklist_items.task_checklist_id)
      )
    )
  )
  WITH CHECK (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_worker_assigned_to_task(
        (SELECT tc.task_id FROM public.task_checklists tc WHERE tc.id = task_checklist_items.task_checklist_id)
      )
    )
  );

CREATE POLICY "task_checklist_items_delete"
  ON public.task_checklist_items FOR DELETE
  USING (
    public.is_super_admin()
    OR (
      tenant_id = public.my_tenant_id()
      AND public.is_tenant_admin_or_manager()
    )
  );

-- -----------------------------------------------------------------------------
-- Oprávnění (RLS stále platí pro authenticated)
-- -----------------------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE, DELETE ON public.checklist_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.checklist_template_items TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.task_checklists TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.task_checklist_items TO authenticated;

-- -----------------------------------------------------------------------------
-- Bezpečnostní doplnění (konzistence s migrací fix_security_advisor)
-- -----------------------------------------------------------------------------

ALTER FUNCTION public.is_tenant_admin_or_manager() SET search_path = public;
ALTER FUNCTION public.is_worker_assigned_to_task(uuid) SET search_path = public;
ALTER FUNCTION public.set_dynamic_checklist_updated_at() SET search_path = public;
