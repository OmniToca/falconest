-- =============================================================================
-- FalcoNest – tasks.title_i18n: lokalizované titulky úkolu pro exporty (PDF) + invalidace
-- =============================================================================
-- ADITIVNÍ: nový sloupec JSONB, výchozí {}. Při změně title/custom_title se překlady
-- bezpečně zahodí v BEFORE triggeru, aby v DB nikdy nezůstaly překlady k jinému zdrojovému textu.
-- =============================================================================

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS title_i18n jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.tasks.title_i18n IS
  'Lokalizované názvy úkolu pro vícejazyčné výstupy (PDF podklady). Očekávaný tvar JSON objektu: '
  '{"translations":{"cs":"…","en":"…","es":"…"},"source_hash":"<hex>"} . '
  'Klíč translations: mapa kódů jazyka (ISO 639-1, shodně s exportLocale v aplikaci) → přeložený řetězec. '
  'Klíč source_hash: volitelný SHA-256 (hex) kanonického zdrojového textu z title + custom_title v době uložení překladů; '
  'klient může sloužit k detekci nekonzistence, ale primární invalidaci zajišťuje trigger při UPDATE title/custom_title. '
  'Prázdný objekt {} znamená „žádné uložené překlady“ — aplikace použije title/custom_title jako fallback.';

-- -----------------------------------------------------------------------------
-- Invalidace: při změně zdrojových polí smažeme celý title_i18n (nastavíme na {}).
-- PROČ databáze, ne jen Dart: úkoly se mění i z jiných klientů, RPC, budoucích integrací
-- nebo opravnými skripty; jediný trigger na tabulce garantuje, že v DB nikdy nezůstane
-- title_i18n vázaný na starý text. Offline-first tím není narušeno — synchronizovaný řádek
-- z Postgresu je kanonický.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tasks_invalidate_title_i18n_before_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- ---------------------------------------------------------------------------
  -- Logika invalidace title_i18n
  -- ---------------------------------------------------------------------------
  -- Účel: Uložené překlady v title_i18n musí vždy odpovídat aktuálnímu znění
  -- zdrojových polí title a custom_title. Jakmile se kterékoli z nich změní,
  -- staré překlady jsou neplatné — držet je by vedlo k PDF/exportům s nesprávným
  -- významem (uživatel vidí nový titulek, ale export by použil starý překlad).
  --
  -- Proč IS DISTINCT FROM místo „<>“: správně rozliší NULL od ne-NULL i shodu
  -- dvou NULL; běžné porovnání by u NULL dávalo nejednoznačné výsledky.
  --
  -- Proč přepisujeme celý title_i18n na '{}': struktura může obsahovat translations,
  -- source_hash i budoucí klíče; jediný bezpečný reset je sjednotit na prázdný objekt.
  -- I když klient ve stejném UPDATE pošle nové title_i18n, BEFORE trigger běží dřív
  -- než zápis — po změně title/custom_title tedy vždy vynulujeme, aby se v DB
  -- nikdy neuložily překlady „k novému“ textu bez explicitního překladního kroku.
  -- ---------------------------------------------------------------------------
  IF OLD.title IS DISTINCT FROM NEW.title
     OR OLD.custom_title IS DISTINCT FROM NEW.custom_title THEN
    NEW.title_i18n := '{}'::jsonb;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.tasks_invalidate_title_i18n_before_update() IS
  'BEFORE UPDATE na tasks: při změně title nebo custom_title nastaví title_i18n na prázdný objekt, '
  'aby se nepoužívaly překlady k předchozímu znění.';

DROP TRIGGER IF EXISTS tasks_invalidate_title_i18n_on_title_change ON public.tasks;
CREATE TRIGGER tasks_invalidate_title_i18n_on_title_change
  BEFORE UPDATE OF title, custom_title ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.tasks_invalidate_title_i18n_before_update();
