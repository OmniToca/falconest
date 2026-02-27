-- Soft-archivace úkolů pro modul Fakturace.
-- Sloupec invoiced_at: NULL = aktivní úkol (zobrazuje se dispečerovi), NOT NULL = vyfakturovaný (schován z Nástěnky a Plachty).
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS invoiced_at timestamptz DEFAULT NULL;

COMMENT ON COLUMN public.tasks.invoiced_at IS 'Kdy byl úkol vyfakturován. NULL = aktivní, NOT NULL = archivovaný (neukazuje se na Nástěnce/Plachtě).';
