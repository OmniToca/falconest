# Audit modulu Apartmány (Lokace / Properties) – FalcoNest

**Datum auditu:** 3. 3. 2025  
**Rozsah:** modul Apartmány (Admin) – výpis, CRUD, kaskáda při mazání, detail (edit dialog), i18n.

---

## 1. KAPACITA A VÝKON (100+ apartmánů)

### Jak je aktuálně řešen výpis apartmánů?

- **Zdroj dat:** `apartmentsProvider` v `lib/features/admin/providers/apartments_provider.dart`.
- **Dotaz:** Jeden **neomezený** SELECT na tabulku `apartments`:
  - `.eq('tenant_id', tenantId)`
  - `.isFilter('deleted_at', null)`
  - `.order('name')`
  - **Žádný `.limit()`** – načítají se **všechny** byty tenanta najednou.

### Stránkování a vyhledávání

- **Stránkování:** **Neexistuje.** Celý seznam se stáhne při otevření obrazovky Apartmány a drží se v paměti (FutureProvider vrací `List<ApartmentRow>`).
- **Vyhledávání:** Pouze **na klientu**. V `admin_apartments_screen.dart` metoda `_computeFiltered()` filtruje již načtený seznam podle textu z `TextField` (název, adresa). Do Supabase se při psaní neposílá žádný dotaz.

### Srovnání s modulem Klienti

- U Klientů byl po auditu zaveden **pagination** (limit 50, offset) a **server-side vyhledávání** (ilike na name/email/phone). Modul Apartmány je zatím **ve stejném stavu jako Klienti před úpravou** – žádný limit, žádná pagination, žádné server-side vyhledávání.

**Shrnutí bodu 1:** Výpis apartmánů **není připraven na 100+ záznamů**. Chybí **limit** v dotazu, **pagination** (cursor/offset) a **server-side vyhledávání**. Při růstu počtu bytů hrozí pomalý první load a vyšší spotřeba paměti.

---

## 2. CRUD A OCHRANA DAT (Závislosti)

### Mazání apartmánu (Soft Delete)

- **Ano.** V seznamu je u každého řádku/karty akce **Smazat**; po potvrzení v dialogu se volá **`_doDelete()`**, která:
  1. Nastaví **`deleted_at`** u záznamu v tabulce **`apartments`**.
  2. **Kaskádově** najde všechny rezervace s `apartment_id = id` a `deleted_at IS NULL` a u každé nastaví `deleted_at`.
  3. **Kaskádově** najde všechny úkoly s `apartment_id = id` a `deleted_at IS NULL` a u každého nastaví `deleted_at`.
  4. Pro každou smazanou entitu (byt, rezervace, úkoly) zapíše záznam do **Enterprise Audit Logu** (SOFT_DELETE resp. SOFT_DELETE_CASCADE s důvodem z i18n).

- **Žádné „odpojení“ (SET NULL):** Úkoly a rezervace se **nemažou záznamově** (nezůstávají s `apartment_id` a prázdným bytem). Jdou **do koše společně s bytem** (všechny mají `deleted_at`). To je záměr – „smazání bytu je destruktivní“.

### Chování v databázi a v aplikaci

- **Databáze:** V migracích mají např. `apartment_services` a `apartment_ical_sources` **ON DELETE CASCADE** na `apartments(id)`. Aplikace však **neprovádí fyzický DELETE**, pouze **UPDATE deleted_at**. K CASCADE tedy u soft delete nedochází; závislosti řeší **aplikace** v `_doDelete()` (rezervace a úkoly).
- **Ochrana proti chybám:** Rezervace a úkoly jsou explicitně procházeny a soft-deletovány. **Nevznikají sirotčí záznamy** (úkoly/rezervace s odkazem na již „smazaný“ byt), protože i ony dostanou `deleted_at`. V UI se všude používá filtr `deleted_at IS NULL`, takže **null reference** na „smazaný byt“ v aktivních seznamech nevzniká.
- **Riziko:** Pokud by v budoucnu přibyly další tabulky s FK na `apartments` (např. nový modul), musí se **ručně doplnit** do `_doDelete()`, jinak by zůstaly záznamy s odkazem na soft-deleted byt. Není zde centrální „cascade soft delete“ z jednoho místa (např. trigger nebo jedna služba).

### Co je v „detailu“ apartmánu?

- **Detail = dialog pro úpravu** (`_EditApartmentDialog`). Není samostatná „jen pro čtení“ obrazovka; uživatel otevře **Upravit** a vidí čtyři záložky:
  1. **Základní údaje** – název, adresa, kód, keybox, check-in/out časy, doba úklidu, poznámky majitele, zóna.
  2. **Služby a ceník** – konfigurace z `apartment_services` (služby z katalogu tenant_services, ceny, spouštěče).
  3. **Majitelé** – přiřazení majitelé z `apartment_owners` (výpis, přidání z klientů, odebrání). Propojení s modulem Klienti je tedy **přítomné**.
  4. **iCal synchronizace** – zdroje kalendářů pro tento byt.

- **Chybějící záložky / kontext:**
  - **Historie rezervací** pro tento byt – uživatel musí jít na obrazovku Rezervace a filtrovat. V detailu bytu není záložka „Rezervace“ s výpisem.
  - **Historie úkolů** pro tento byt – stejně tak úkoly se řeší jinde (Úkoly / kalendář). V detailu bytu není záložka „Úkoly“ s výpisem.
  - **Stav bytu (Obsazeno / K úklidu / Uklizeno)** se v některých částech aplikace počítá dynamicky (např. `apartment_status_provider`), v edit dialogu se přímo nezobrazuje souhrn „aktuální stav + nejbližší rezervace/úkol“.

**Shrnutí bodu 2:**  
- **Soft delete je implementovaný** a **kaskáda na rezervace a úkoly** je řešená v kódu (vše jde do koše, audit log). Ochrana proti sirotčím záznamům a null reference v aktivních view je zajištěna.  
- **V detailu (edit dialogu)** je propojení s **Majiteli** (Klienti) a **iCal**. Chybí **přehled rezervací a úkolů** pro tento byt přímo v dialogu.

---

## 3. i18n (Lokalizace)

### UI – obrazovka a dialogy

- **admin_apartments_screen.dart** používá **`.tr()`** a klíče z překladů (např. `admin.apartments_delete`, `admin.tab_basic_info`, `admin.section_owners`, `common.cancel`). Štítky stavů bytu se mapují přes **`_statusKeys`** (české hodnoty z DB → i18n klíče).  
- Formuláře, tlačítka, prázdné stavy, potvrzení mazání – **většina textů je napojená na i18n**.

### Hardcoded české / technické texty

- **apartments_provider.dart:**
  - **`_statusFallback = 'Uklizeno'`** – výchozí hodnota pro sloupec status; používá se i v `toMap()`. Je to zároveň hodnota ukládaná do DB, takže pokud by se někde zobrazovala bez překladu, byla by česky.
  - **`_parseStatus`** vrací tento fallback; **`_statusKeys`** v obrazovce pak mapuje české stringy (Uklizeno, K úklidu, …) na klíče – zobrazení je tedy lokalizované, ale **v modelu a v DB zůstávají české hodnoty**.

- **apartment_owners_provider.dart:**
  - **`throw StateError('Profil majitele nebyl vytvořen.');`** – chybová hláška při vytváření majitele. Pokud se tato výjimka zobrazí uživateli (např. v SnackBaru), **není lokalizovaná**.

- **admin_apartments_screen.dart:**
  - **`throw Exception('Insert apartments nevrátil id');`** – technická výjimka po insertu; při zobrazení v UI by byla česky/anglicky dle runtime.
  - **`print('--- CHYBA MAZÁNÍ APARTMÁNŮ: $e');`** a **`print('--- CHYBA ÚPRAVY APARTMÁNU: $e');`** – ladící výpisy v češtině (neviditelné pro koncového uživatele, ale nekonzistentní s potenciálním anglickým prostředím).
  - **`print('>>> Sloupce v tabulce apartments...')`** – návod pro vývojáře; česky.

- **Mapování stavů:** Konstanta **`_statusKeys`** a **`_statusChipColors`** používají české literály (`'Uklizeno'`, `'K úklidu'`, …), protože tak mohou být hodnoty uložené v DB. To je **úmysl** pro kompatibilitu s existujícími daty; zobrazení je přes `.tr()` lokalizované.

**Shrnutí bodu 3:**  
- **Většina UI je napojená na i18n.**  
- **Hardcoded** jsou: **StateError** v `apartment_owners_provider.dart` (Profil majitele nebyl vytvořen.), **Exception** a **print** v `admin_apartments_screen.dart`. Fallback **`'Uklizeno'`** v provideru je hodnota pro DB/model; zobrazení je řešené přes klíče v obrazovce.

---

## Doporučení: 2–3 nejkritičtější vylepšení

### 1. Stránkování a server-side vyhledávání (výkon a škálovatelnost)

- **Problém:** Při 100+ apartmánech se všechna načítají najednou a vyhledávání běží pouze v paměti.  
- **Návrh:** Stejný směr jako u Klientů:
  - V repozitáři (nebo přímo v provideru) zavést **paginovaný dotaz** (např. `.range(offset, offset + limit - 1)` s rozumným limitem 50).
  - **Server-side vyhledávání:** při neprázdném dotazu použít filtr např. `.or('name.ilike.%query%,address.ilike.%query%')` a stejný limit/range.
  - V UI **nekonečný scroll** (ScrollController, na konec volání `loadMore()`) a **debounce** pro vyhledávací pole (např. 300–500 ms), které zapříčiní nový dotaz s dotazem a resetem stránkování.
- **Důsledek:** První obrazovka Apartmány zvládne 100+ bytů bez velkého zatížení a konzistentní chování s modulem Klienti.

### 2. Detail bytu: záložka Rezervace a Úkoly (kontext a UX)

- **Problém:** V edit dialogu bytu uživatel nevidí „co se na bytě děje“ – rezervace a úkoly musí hledat jinde.  
- **Návrh:** Do `_EditApartmentDialog` přidat další záložky (nebo jednu kombinovanou):
  - **Rezervace** – výpis rezervací s `apartment_id = tento byt` (např. z provideru typu `reservationsForApartmentProvider(apartmentId)`), řazení od nejbližších, pouze aktivní (ne deleted, volitelně bez cancelled), s možností kliknout a otevřít edit rezervace.
  - **Úkoly** – výpis úkolů s `apartment_id = tento byt` (např. z existujícího zdroje úkolů filtrovaného na apartment_id), řazení podle data, pouze aktivní; kliknutí → edit úkolu.
- **Důsledek:** Jedno místo pro správu bytu včetně kontextu rezervací a úkolů; méně přepínání mezi obrazovkami.

### 3. i18n a konzistence chybových hlášek

- **Problém:** Chybové hlášky v providerech a výjimkách jsou česky; při zobrazení v UI (SnackBar, dialog) nejsou lokalizované.  
- **Návrh:**
  - V **apartment_owners_provider.dart** nepoužívat `StateError('Profil majitele nebyl vytvořen.')` jako finální text pro uživatele. Buď používat kód a v UI mapovat na klíč (např. `admin.owners_error_profile_not_created`), nebo před zobrazením sestavit zprávu z `'admin.owners_error_profile_not_created'.tr()`.
  - V **admin_apartments_screen.dart** při zachycení výjimky po insertu/update/mazání zobrazit **lokalizovanou zprávu** (např. `admin.apartments_save_error` / `admin.apartments_delete_error` s parametrem pro technický detail), místo přímého `'$e'`.
  - **Print** zprávy ponechat pro vývoj (ideálně za `kDebugMode`), případně sjednotit jazyk nebo je odstranit z produkčního kódu.
- **Důsledek:** Konzistentní B2B SaaS vícenárodní podpora a srozumitelné chybové hlášky ve zvoleném jazyce.

---

**Konec reportu.**  
Pro implementaci doporučení lze postupovat po pořadí: nejdříve bod 1 (výkon), potom bod 2 (záložky Rezervace/Úkoly v detailu bytu) a bod 3 (i18n chyb).
