-- BUGFIX: Řešení chybějícího sloupce created_by při automatickém generování úkolu.
-- Klientský portál (owner_reservations_screen) při vytváření rezervace automaticky
-- vytváří úkol (úklid) a potřebuje uložit ID tvůrce pro audit.
-- Sloupec je nullable – existující úkoly a systémově generované úkoly mohou mít NULL.
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id);

COMMENT ON COLUMN public.tasks.created_by IS 'Profil tvůrce úkolu – audit; NULL u systémově generovaných nebo starých záznamů.';

NOTIFY pgrst, 'reload schema';
