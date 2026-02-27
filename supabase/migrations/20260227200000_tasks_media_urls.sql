-- =============================================================================
-- FalcoNest – Sloupec media_urls do tabulky tasks (multi-photo)
-- =============================================================================
-- PROČ: Hlášení závad od pracovníků může mít více fotek. Budoucí použití:
-- focení pasů u check-inu, focení čistého apartmánu po úklidu.
-- text[] s defaultem prázdného pole – PostgreSQL nativní pole URL řetězců.
-- =============================================================================

ALTER TABLE public.tasks
ADD COLUMN IF NOT EXISTS media_urls text[] DEFAULT '{}';

COMMENT ON COLUMN public.tasks.media_urls IS 'URL fotek v Supabase Storage (falconest_media/tasks/). Pro hlášení závad, check-in pasy, úklid fotodokumentace.';
