-- =============================================================================
-- FalcoNest – Interní poznámka manažera u rezervace
-- Není synchronizována do mobilní aplikace personálu, pouze pro admin dashboard.
-- =============================================================================

ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS internal_note TEXT;

COMMENT ON COLUMN public.reservations.internal_note IS 'Interní poznámka manažera. Not synced to mobile app, for admin dashboard only.';
