# Plán refaktoringu: Šablony (`tenant_message_templates`) a Automatizace (`automation_rules`)

**Cíl:** Oddělit kanály (SMS / E-mail / WhatsApp) v datech i UI, doplnit předmět e-mailu, vícejazyčnost v jednom záznamu (JSONB), filtrovat šablony podle kanálu v pravidlech a zobrazit SMS počítadlo jen pro SMS.

**Princip:** *Additive development* – žádné mazání řádků; staré sloupce zůstanou jako fallback pro existující klienty a postupný přechod.

---

## A) Potřebné SQL migrace (additive)

### A.1 Rozšíření / sjednocení kanálu

- [ ] **Sjednotit pojmenování s `automation_channel`** (`email` | `sms` | `whatsapp` v DB enumu automatizací) a se současným `channel` (`whatsapp_link` | `sms` | `email`):
  - Migrace dat: `UPDATE ... SET channel = 'whatsapp' WHERE channel = 'whatsapp_link'` (nebo ponechat oba významy a přidat novou hodnotu – doporučeno **jedna canonical hodnota** `whatsapp` + jednorázový UPDATE).
  - `ALTER` constraint na `channel` (nebo nový sloupec `channel_type` – viz níže), aby povoloval výhradně: `sms`, `email`, `whatsapp` (a dočasně `whatsapp_link` jen pokud nechceme okamžitý UPDATE – lepší je UPDATE + jeden CHECK).

- [ ] **Volitelný alias pro čitelnost:** přidat sloupec `channel_type text` **GENERATED ALWAYS AS (channel) STORED** pouze pokud přejmenujeme `channel` → interně stačí jeden sloupec; jinak ponechat jeden sloupec `channel` jako zdroj pravdy a v dokumentaci ho nazývat „typ kanálu“.

*Doporučení:* nepřidávat duplicitní `channel_type`, pokud `channel` už plní roli; stačí **upravit CHECK** a **migrovat hodnoty**.

### A.2 E-mailový předmět

- [ ] `ALTER TABLE ... ADD COLUMN IF NOT EXISTS email_subject text NULL;`
- [ ] Komentář: „Předmět pro kanál `email`; u SMS/WhatsApp ignorováno.“
- [ ] Žádný `NOT NULL` na úrovni DB pro všechny řádky – validace v aplikaci pro `channel = email`.

### A.3 Více jazyků v jednom záznamu (JSONB)

- [ ] `ADD COLUMN translations jsonb NULL DEFAULT NULL;`
- [ ] Doporučený tvar (konvence v týmu – zafixovat v komentáři k sloupci):

```json
{
  "cs": { "name": "Volitelně přepsaný název", "body": "…", "subject": "…" },
  "en": { "body": "…" },
  "es": { "body": "…" }
}
```

- [ ] `subject` uvnitř jazyka jen pro `email` (nebo globální `email_subject` jako výchozí + override v jazyce).
- [ ] **Backfill (additive):** pro existující řádky:
  - pokud `language_code IS NOT NULL`, vložit do `translations` jeden klíč (např. `language_code`) s `body` zkopírovaným z `body` a případně `name`;
  - pokud `language_code IS NULL`, ponechat `translations` NULL a nechat aplikaci číst legacy `body` / `name`.

### A.4 Indexy pro výkon a filtrování

- [ ] `CREATE INDEX ... ON tenant_message_templates (tenant_id, channel) WHERE deleted_at IS NULL;`
- [ ] Volitelně GIN na `translations` pouze pokud budete často vyhledávat uvnitř JSON.

### A.5 Automatizace (`automation_rules`)

- [ ] Ověřit, že `template_id` FK zůstává; po sjednocení kanálů šablony **doplnit kontrolu konzistence** (volitelné v DB):
  - **CHECK** nebo trigger: `EXISTS (SELECT 1 FROM tenant_message_templates t WHERE t.id = template_id AND t.channel = automation_rules.channel)` – *náročnější na migraci*, pokud historická data neodpovídají; lze řešit až po backfillu kanálů.
- [ ] Alternativa k triggeru: pouze aplikační validace při uložení pravidla (rychlejší rollout).

### A.6 Edge / enqueue

- [ ] Funkce čtoucí šablonu (`automation-enqueue`, šablony v SQL v migraci) musí po změně struktury **číst `body`** z:
  - prioritně z `translations` podle jazyka entity, jinak `body`,
  - pro e-mail sjednotit **předmět** z `email_subject` / `translations[lang].subject`.

*(Samostatný task v implementační fázi – není nutné v první migraci měnit všechny funkce, ale plán musí počítat s úpravou SELECTů.)*

---

## B) Změny v Dart modelech (DTO, JSONB)

### B.1 `MessageTemplateRow` (nebo nový `MessageTemplateDto`)

- [ ] Přidat nullable pole: `emailSubject`, `translations`.
- [ ] **Parsování `translations`:** `Map<String, dynamic>?` → typovaný helper (např. `MessageTemplateTranslations` s `Map<String, TemplateLocaleBlock>` kde `TemplateLocaleBlock` má `name?`, `body?`, `subject?`).
- [ ] **Zpětná kompatibilita:** pokud `translations == null`, použít `body`, `name`, `languageCode` jako dosud.
- [ ] **Kanál:** property `channel` sjednotit s enumem v aplikaci (`sms` / `email` / `whatsapp`); mapovat legacy `whatsapp_link` při `fromJson` jednorázově na `whatsapp`.
- [ ] `toJson` / `toMap` pro insert/update: serializovat `translations` jako JSON mapu; neposílat prázdný objekt, pokud NULL.

### B.2 Vrstva domény / služby

- [ ] `TemplatePlaceholderService` / nová utilita: **`resolveTemplateBody(template, Locale guestLocale)`** – vrátí text z `translations` nebo fallback na `body`.
- [ ] Pro e-mail: **`resolveEmailSubject(template, locale)`** – `email_subject` + případně překlad v JSONB.

### B.3 `AutomationRuleRow` / formulář

- [ ] Při výběru šablony držet v paměti **kanál pravidla** a **templateId**; validovat shodu kanálů před uložením (server + klient).

### B.4 Repozitáře

- [ ] `select` v repozitářích rozšířit o `email_subject`, `translations` (pokud ne `*`).
- [ ] Žádné odstranění starých polí ze selectu.

---

## C) Návrh změn ve Flutter UI

### C.1 Obrazovka / dialog „Šablona zprávy“ (Templates)

1. **Krok 1 – výběr kanálu (segmentovaný přístup)**  
   - Radio / `SegmentedButton` / první dropdown: **SMS | E-mail | WhatsApp** (hodnoty sjednocené s DB).  
   - Po změně kanálu: vyčistit nebo potvrdit nekompatibilní pole (additive: varování místo mazání).

2. **Pole závislá na kanálu**  
   - **Společné:** název šablony (interní), `key`, trigger kontext, pořadí.  
   - **SMS:** hlavní text + **`SmsCounterInfo`** / `SmsTextField` **pouze když `channel == sms`**.  
   - **E-mail:** `TextField` pro **předmět** (globální + volitelně per jazyk v editoru překladů).  
   - **WhatsApp:** text těla (bez SMS segmentů); nápověda k `wa.me` / limity odlišné od SMS.

3. **Více jazyků (jedna šablona)**  
   - UI: záložky nebo dropdown „Jazyk překladu“ (cs / en / es / …) editující **podčást** `translations[code]`.  
   - Prázdný jazyk = neodesílat klíč do JSON (nebo explicitní „použít výchozí“).  
   - Zachovat zobrazení **legacy** režimu: pokud `translations` null, zobrazit jedno pole `body` jako dosud.

4. **i18n**  
   - Všechny nové popisky (`communication.template_channel_*`, `communication.template_email_subject`, `communication.template_translations_hint`, …) do `cs.json` / `en.json` / `es.json`.

### C.2 Dialog / formulář „Pravidlo automatizace“ (`automation_rules`)

1. **Pořadí polí**  
   - **Nejdřív Kanál** (SMS / E-mail / WhatsApp) – stejný enum jako u šablon.  
   - **Poté** trigger, offset, quiet hours, …  
   - **Šablona:** `DropdownButtonFormField` s dotazem na šablony **filtrované** `WHERE channel = vybraný_kanál` (a `deleted_at IS NULL`).

2. **Změna kanálu**  
   - Pokud už je vybraná šablona z jiného kanálu → reset `template_id` nebo dialog „Změna kanálu zruší výběr šablony“.

3. **Validace**  
   - Před odesláním: `rule.channel == selectedTemplate.channel` (porovnání normalizovaných stringů / enum).

### C.3 Seznam šablon (tabulka / karty)

- [ ] Sloupec nebo badge **Kanál** (barva / ikona).  
- [ ] Filtrování podle kanálu (volitelně druhá iterace).

### C.4 Worker / Message template selector

- [ ] Při výběru šablony pro úkol zohlednit **kanál** (WhatsApp stávající flow) a v budoucnu SMS šablony zvlášť – podle produktu.

---

## D) Shrnutí rizik a pořadí dodání

| Fáze | Obsah |
|------|--------|
| **1** | Migrace: `email_subject`, `translations`, úprava CHECK + UPDATE `whatsapp_link` → `whatsapp`, backfill JSONB |
| **2** | DTO + repozitáře + resolve helpery |
| **3** | UI šablon (kanál → podmíněná pole + SMS counter) |
| **4** | UI automatizace (kanál první → filtrované šablony) |
| **5** | Úpravy Edge `automation-enqueue` / dispatch pro subject a vícejazyčné `body` |

---

## E) Poznámka k pravidlům projektu

- **Additive:** žádné `DROP COLUMN`; legacy `body` + `language_code` zůstávají do doby, než všechny klienty čtou `translations`.  
- **i18n:** veškeré nové řetězce ve formulářích pouze přes lokalizaci.  
- **Clean Architecture:** mapování JSONB v modelech/repozitářích, ne ve widgetech.  
- **RLS:** nové sloupce automaticky podléhají stávajícím politikám na `tenant_message_templates` (bez změny politik, pokud nepřidáváte nové tabulky).

---

*Dokument slouží jako architektonický plán; konkrétní čísla migrací a názvy souborů doplní implementující vývojář.*
