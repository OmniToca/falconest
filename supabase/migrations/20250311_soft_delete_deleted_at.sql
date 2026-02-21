-- Soft delete: přidání sloupce deleted_at (timestamptz, nullable) do hlavních provozních tabulek.
-- Místo DELETE se volá UPDATE deleted_at = now(); záznamy s deleted_at IS NOT NULL se v aplikaci neukazují.
-- =============================================================================

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

ALTER TABLE public.apartments
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

COMMENT ON COLUMN public.tasks.deleted_at IS 'Soft delete: když NOT NULL, záznam je považován za smazaný a v UI se neukazuje.';
COMMENT ON COLUMN public.apartments.deleted_at IS 'Soft delete: když NOT NULL, záznam je považován za smazaný a v UI se neukazuje.';
COMMENT ON COLUMN public.profiles.deleted_at IS 'Soft delete: když NOT NULL, profil je považován za smazaný a v UI se neukazuje.';
COMMENT ON COLUMN public.reservations.deleted_at IS 'Soft delete: když NOT NULL, rezervace je považována za smazanou a v UI se neukazuje.';

CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at ON public.tasks(deleted_at);
CREATE INDEX IF NOT EXISTS idx_apartments_deleted_at ON public.apartments(deleted_at);
CREATE INDEX IF NOT EXISTS idx_profiles_deleted_at ON public.profiles(deleted_at);
CREATE INDEX IF NOT EXISTS idx_reservations_deleted_at ON public.reservations(deleted_at);
