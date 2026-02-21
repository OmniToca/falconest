-- Přidání sloupce reservation_id do tasks – vazba úkolu na rezervaci.
-- Umožňuje mazání „duchů“ při změně termínu rezervace.
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS reservation_id uuid REFERENCES public.reservations(id) ON DELETE CASCADE;

COMMENT ON COLUMN public.tasks.reservation_id IS 'Rezervace, pro kterou byl úkol vygenerován. Pro mazání při změně termínu.';
