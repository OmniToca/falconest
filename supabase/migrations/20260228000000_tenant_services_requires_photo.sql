-- =============================================================================
-- FalcoNest – Sloupec requires_photo do tenant_services
-- =============================================================================
-- PROČ: Služby typu "Úklid s fotkou" vyžadují fotodokumentaci při dokončení úkolu.
-- Pracovník nebude moci úkol dokončit bez nahrané fotky (stav apartmánu, pasy atd.).
-- Propagace do tasks.metadata proběhne v generátoru úkolů (další fáze).
-- =============================================================================

ALTER TABLE public.tenant_services
ADD COLUMN IF NOT EXISTS requires_photo boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.tenant_services.requires_photo IS 'Vyžadovat fotodokumentaci při dokončení úkolu (např. fotka apartmánu, ofocené pasy).';
