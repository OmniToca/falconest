-- Data-driven menu visibility & module dependencies
-- Adds show_in_menu (default true) and parent_module_key (nullable).
-- automatic_tasks: hidden from menu, child of 'tasks'.

ALTER TABLE public.modules
  ADD COLUMN IF NOT EXISTS show_in_menu boolean NOT NULL DEFAULT true;

ALTER TABLE public.modules
  ADD COLUMN IF NOT EXISTS parent_module_key text;

COMMENT ON COLUMN public.modules.show_in_menu IS 'When false, module is not shown in the sidebar menu (e.g. sub-features like automatic_tasks).';
COMMENT ON COLUMN public.modules.parent_module_key IS 'Optional parent module key; e.g. automatic_tasks has parent_module_key = tasks.';

UPDATE public.modules
SET show_in_menu = false,
    parent_module_key = 'tasks'
WHERE key = 'automatic_tasks';
