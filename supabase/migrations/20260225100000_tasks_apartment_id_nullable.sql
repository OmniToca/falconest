-- FalcoNest – apartment_id nullable pro úkoly na úrovni agentury (ne na konkrétní byt).
--
-- PROČ: Alert úkoly z hlášení nepřítomnosti (dovolená, nemoc) patří celé agentuře,
-- ne konkrétnímu apartmánu. Dispečer je vidí v kalendáři jako nepřiřazené.
ALTER TABLE public.tasks
  ALTER COLUMN apartment_id DROP NOT NULL;

COMMENT ON COLUMN public.tasks.apartment_id IS 'FK na apartment – NULL u úkolů na úrovni agentury (např. alert z nepřítomnosti).';
