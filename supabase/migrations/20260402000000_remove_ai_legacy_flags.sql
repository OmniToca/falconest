-- =============================================================================
-- FalcoNest – Odstranění legacy příznaků rezervace (B2B operativa)
-- Sloupce nebyly napojené na finance; UI a modely je již nepoužívají.
-- =============================================================================

ALTER TABLE public.reservations DROP COLUMN IF EXISTS is_owner_block;
ALTER TABLE public.reservations DROP COLUMN IF EXISTS agency_collects_payment;

NOTIFY pgrst, 'reload schema';
