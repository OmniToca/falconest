-- FalcoNest – Fáze 2: vazba šablony checklistu na konkrétní službu u konkrétního apartmánu (apartment_services).
--
-- PROČ: Tabulka apartment_services je řádek „tato služba z katalogu je u tohoto bytu aktivní + override“;
-- checklist_template_id doplňuje: která šablona checklistu se má použít pro tuto kombinaci (byt + služba).
-- ON DELETE SET NULL: smazání šablony v checklist_templates nesmaže vazbu služby u bytu, jen zruší přiřazení šablony.

ALTER TABLE public.apartment_services
  ADD COLUMN IF NOT EXISTS checklist_template_id uuid REFERENCES public.checklist_templates (id) ON DELETE SET NULL;

COMMENT ON COLUMN public.apartment_services.checklist_template_id IS
  'Volitelná šablona checklistu pro tuto službu v rámci tohoto jednoho apartmánu (override na úrovni bytu). NULL = žádná konkrétní šablona z katalogu checklistů pro tuto vazbu nebo výchozí chování aplikace.';

CREATE INDEX IF NOT EXISTS idx_apartment_services_checklist_template_id
  ON public.apartment_services (checklist_template_id)
  WHERE checklist_template_id IS NOT NULL;
