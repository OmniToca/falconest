-- =============================================================================
-- FalcoNest – tenant_services.name_i18n: překlady názvu služby v katalogu
-- =============================================================================
-- ADITIVNÍ: nový sloupec JSONB, výchozí {}. Při vytvoření úkolu s service_id aplikace
-- zkopíruje tuto mapu do tasks.title_i18n (snapshot) — historické PDF/uzamčené měsíce
-- nezávisí na budoucích úpravách ceníku.
-- =============================================================================

ALTER TABLE public.tenant_services
  ADD COLUMN IF NOT EXISTS name_i18n jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.tenant_services.name_i18n IS
  'Lokalizované názvy služby v katalogu agentury (zdroj pro snapshot do tasks.title_i18n při INSERT úkolu). '
  'Očekávaný tvar shodný s tasks.title_i18n: '
  '{"translations":{"cs":"…","en":"…","es":"…"},"source_hash":"<hex volitelně>"} . '
  'Klíč translations: ISO 639-1 → přeložený název služby. '
  'Prázdný objekt {} = žádné uložené překlady v katalogu — nové úkoly dostanou title_i18n až po doplnění zde nebo ručně v úkolu.';
