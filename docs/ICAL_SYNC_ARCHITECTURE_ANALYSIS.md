# Architektonická analýza: Přechod z Excel importu na automatizovaný iCal Sync

**Datum analýzy:** 2025-03-01  
**Kontext:** Podpora iCal odkazu (Airbnb, Booking, Smoobu) pro automatickou synchronizaci rezervací. Cílem je škálovatelnost (20 000+ bytů), idempotence (žádné duplicity), CORS workaround přes Supabase Edge Function.

---

## 1. Databázová připravenost

### 1.1 Tabulka `reservations` – externí identifikátor pro idempotenci

**Aktuální stav:** Tabulka **nemá** sloupec pro ukládání externího ID (ical_uid, external_uid). Existuje pouze `reference_number` – auto-generovaný identifikátor (např. RES-A8B3K9) pro podporu a importy, ale ten nevzniká z iCal.

| Sloupec | Typ | Účel |
|---------|-----|------|
| `external_uid` | text | **CHYBÍ.** Unikátní ID z iCal (VEVENT UID). UNIQUE constraint na (tenant_id, external_uid). Slouží pro: „už tuto rezervaci máme“ → skip insert. Idempotence syncu. |

**Doporučení:** Přidat `external_uid text UNIQUE` s parciálním unikátním indexem (nebo UNIQUE NULLS NOT DISTINCT), protože ručně vytvořené rezervace a Excel importy nemají external_uid (NULL). Kontrola duplicit: `WHERE external_uid = ? AND tenant_id = ?`.

**Alternativa názvu:** `ical_uid` – sémanticky jasnější pro iCal, ale `external_uid` je obecnější (budoucí API, webhooky).

---

### 1.2 Ukládání iCal URL – `apartments` vs. nová tabulka

**Aktuální stav:** Tabulka `apartments` **nemá** sloupec pro iCal URL.

**Možnost A – sloupec na `apartments`:**

| Sloupec | Typ | Poznámka |
|---------|-----|----------|
| `ical_url` | text | **CHYBÍ.** Jeden odkaz na byt. Pro Airbnb/Booking: jeden channel zpravidla = jeden odkaz. Pokud má byt více channelů, nelze rozlišit. |

**Možnost B – nová tabulka `apartment_ical_sources`:**

| Sloupec | Typ | Účel |
|---------|-----|------|
| id | uuid | PK |
| tenant_id | uuid | FK → tenants |
| apartment_id | uuid | FK → apartments |
| ical_url | text | URL .ics (Airbnb, Booking, Smoobu…) |
| source_label | text | Lidský název (např. "Airbnb", "Booking.com") |
| last_synced_at | timestamp | Kdy byl naposledy sync |
| created_at, updated_at | timestamp | Audit |
| UNIQUE(apartment_id, source_label) | - | Jeden odkaz na channel a byt |

**Doporučení:** Možnost B – škálovatelnost a flexibilita. Jeden byt může mít více channelů (Airbnb + Booking). Pro 20k bytů je batch sync realistický – projít řádky s neprázdným `ical_url`.

---

## 2. Analýza současného Excel importu

### 2.1 Tok dat – kde se logika nachází

| Krok | Soubor | Metoda / místo | Popis |
|------|--------|----------------|-------|
| 1. UI – výběr souboru | admin_reservations_screen.dart | `_importCsv()` (ř. 438) | FilePicker → bytes |
| 2. Parsing + insert | reservation_import_service.dart | `processImport()` | Excel.decodeBytes → řádky → insert do `reservations` + `reservation_services` |
| 3. Refresh UI | admin_reservations_screen.dart | `ref.invalidate(adminReservationsProvider)` | Obnovení seznamu rezervací |
| 4. Generování úkolů | admin_tasks_screen.dart | Manuální tlačítko → `generateSmartTasks()` | **Neprobíhá automaticky po importu.** |

### 2.2 Generování úkolů – vazba na task_assignment_engine

- `AdminTasksNotifier.generateSmartTasks()` (admin_tasks_provider.dart, ř. 504) načítá:
  - `adminReservationsProvider` → všechny rezervace z DB
  - `apartments`, `apartment_services`, `tenant_services`, `reservation_services`
- Volá **task_assignment_engine** pro přiřazení personálu (zamčený soubor – pouze využití, bez úprav).
- Úkoly se zakládají na rezervacích v DB – **zdroj dat (Excel, iCal, ruční) je irelevantní**.

**Závěr:** Pro iCal stačí vložit rezervace do `reservations` (a případně `reservation_services`). Existující `generateSmartTasks` je můžeme použít bez změny. Po iCal syncu lze buď automaticky volat `generateSmartTasks`, nebo ponechat manuální spuštění jako u Excelu.

### 2.3 Excel vs. iCal – mapování dat

| Excel | iCal VEVENT | reservations |
|-------|-------------|--------------|
| apartment_code | – | Musíme mapovat (např. SUMMARY, LOCATION, DESCRIPTION → apartment) |
| guest_name | SUMMARY | guest_name |
| check_in / check_out | DTSTART, DTEND | check_in, check_out, arrival_time, departure_time |
| – | UID | external_uid (nový sloupec) |
| Služby (srv_*) | – | Obvykle ne v iCal; lze doplnit z apartment_services nebo nechat prázdné |

**Obtíž u iCal:** Párování VEVENT → apartment. Airbnb/Booking typicky vrací název bytu v SUMMARY nebo LOCATION. Potřeba mapování: text (název/kód) → `apartments.code` nebo `apartments.name`.

---

## 3. Návrh architektury pro iCal Sync

### 3.1 Přehled komponent

```
┌─────────────────┐     ┌──────────────────────────┐     ┌─────────────────┐
│  Flutter App    │────▶│  Supabase Edge Function  │────▶│  Airbnb/Booking  │
│  (Admin)        │     │  ical-fetch              │     │  iCal URL        │
└────────┬────────┘     └────────────┬─────────────┘     └─────────────────┘
         │                            │
         │ 1. POST { ical_url }       │ 2. fetch(ical_url)
         │                            │ 3. parse .ics → JSON
         │ 4. JSON events             │
         ▼                            │
┌─────────────────────────────────────────────────────────┐
│  Flutter: filter by external_uid, insert, generateTasks  │
└─────────────────────────────────────────────────────────┘
```

### 3.2 Supabase Edge Function `ical-fetch`

**Účel:** Proxy pro stažení a parsování .ics (obcházení CORS na webu).

**Vstup (POST JSON):**
```json
{
  "ical_url": "https://www.airbnb.com/calendar/ical/xxxxx.ics"
}
```

**Výstup (JSON):**
```json
{
  "events": [
    {
      "uid": "abc123@airbnb.com",
      "summary": "Jan Novák - Apartmán Slunce",
      "dtstart": "2026-03-15T14:00:00Z",
      "dtend": "2026-03-22T10:00:00Z",
      "description": "...",
      "location": "Apartmán Slunce"
    }
  ],
  "error": null
}
```

**Implementace (TypeScript/Deno):**
1. Přijmout POST s `ical_url`.
2. `fetch(ical_url)` – Edge Function nemá CORS omezení.
3. Parsovat .ics (knihovna: `ical.js` nebo vlastní regex pro VEVENT).
4. Extrahovat: UID, SUMMARY, DTSTART, DTEND, DESCRIPTION, LOCATION.
5. Vrátit JSON s polem `events`.

**Bezpečnost:** Ověřit `auth.uid()` (pouze přihlášený uživatel). Volitelně whitelist domén (airbnb.com, booking.com, …).

### 3.3 Mapování VEVENT → apartment

Problém: iCal neobsahuje `apartment_id`. Možnosti:

1. **SUMMARY / LOCATION obsahuje kód bytu** – regex nebo klíčová slova → `apartments.code`.
2. **Jeden iCal URL = jeden byt** – při ukládání URL v `apartment_ical_sources` je vazba zřejmá.
3. **DESCRIPTION / custom pole** – platformy mohou vkládat kód bytu; závisí na providerovi.

**Doporučení:** Pro `apartment_ical_sources` platí 1 URL = 1 byt. Při syncu tedy známe `apartment_id` z řádku tabulky. Odpadá nutnost hádat byt z textu.

### 3.4 Flutter – tok po obdržení JSON

```
1. Zavolat Edge Function s ical_url (z apartment_ical_sources nebo ručně zadaným).
2. Obdržet { events: [...] }.
3. Načíst existující external_uid z reservations:
   SELECT external_uid FROM reservations
   WHERE tenant_id = ? AND external_uid = ANY(?)
4. Filtrovat: events filtrovat na ty, jejichž uid NENÍ v existujících.
5. Pro každý nový event:
   - Mapovat apartment (z kontextu syncu – jeden byt, nebo z mapování).
   - INSERT do reservations (včetně external_uid, check_in, check_out, guest_name ze SUMMARY).
6. ref.invalidate(adminReservationsProvider).
7. Volitelně: notifier.generateSmartTasks() pro nové rezervace.
```

### 3.5 Idempotence – detekce duplicit

```sql
-- Před insertem: kontrolovat, zda external_uid již existuje
SELECT id FROM reservations
WHERE tenant_id = :tenant_id AND external_uid = :uid AND deleted_at IS NULL;

-- Pokud existuje → skip (nebo UPDATE při změně termínu, podle byznysu).
```

**Škálování:** Pro 20k bytů a tisíce událostí – batch kontrola: `WHERE external_uid = ANY(array['uid1','uid2',...])` v jednom dotazu. Insertovat pouze nové.

### 3.6 Automatický vs. manuální sync

**Manuální:** Tlačítko „Sync iCal“ u bytu nebo v přehledu. Uživatel spustí, když chce.

**Automatický:** Cron job (pg_cron) volá Edge Function v pravidelných intervalech pro záznamy z `apartment_ical_sources`. Edge Function nemůže přímo zapisovat do DB (potřebuje service_role). Možnosti:
- **A:** Cron volá Edge Function → ta vrací JSON; jiná Edge Function nebo DB funkce přijme JSON a zapíše (RPC).
- **B:** Cron spouští Edge Function, která sama fetche iCal, parsuje a zapisuje do DB (service_role).

Pro plnou automatizaci je vhodné řešení B – jedna Edge Function „ical-sync“, která projde `apartment_ical_sources` a pro každý aktivní řádek provede fetch → parse → upsert do reservations.

---

## 4. Chybějící DB sloupce – souhrn

| Tabulka | Sloupec | Typ | Účel |
|---------|---------|-----|------|
| reservations | external_uid | text | Idempotence – UNIQUE(tenant_id, external_uid), NULL pro ruční/Excel |
| apartment_ical_sources | (nová tabulka) | - | tenant_id, apartment_id, ical_url, source_label, last_synced_at |

---

## 5. Doporučený flow (krok za krokem)

### Fáze 1 – Manuální sync (MVP)
1. Migrace: přidat `external_uid` do reservations, vytvořit `apartment_ical_sources`.
2. Edge Function `ical-fetch`: POST { ical_url } → JSON events.
3. Flutter: UI pro zadání iCal URL u bytu (uložení do apartment_ical_sources), tlačítko „Stáhnout a importovat“.
4. Volání Edge Function → filtrace dle external_uid → insert nových → invalidate providerů → volitelně generateSmartTasks.

### Fáze 2 – Automatizace
5. Edge Function `ical-sync`: načte apartment_ical_sources, pro každý řádek fetche, parsuje, upsertuje do reservations (service_role).
6. pg_cron: denní nebo hodinové volání `ical-sync`.

---

## 6. Rizika a omezení

- **task_assignment_engine.dart** – zamčený; pouze použití přes generateSmartTasks, žádné úpravy.
- **Mapování bytu** – pokud jeden iCal URL obsahuje více bytů (kolekce), bude potřeba složitější mapování (SUMMARY, LOCATION).
- **Rate limiting** – Airbnb/Booking mohou omezovat četnost requestů na iCal URL; batch sync musí respektovat rozumné intervaly.
- **Formát .ics** – různí poskytovatelé mohou mírně lišit formát; parser musí být odolný (optional pole, fallbacky).
