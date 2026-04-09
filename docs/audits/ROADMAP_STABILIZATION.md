# FalcoNest – Plán stabilizace a vylepšení stávajících modulů

**Datum:** 2026-03-28  
**Účel dokumentu:** Tento soubor je **živý plán** (living document) pro stabilizaci, dotažení a polish existujících částí aplikace FalcoNest. Slouží jako hlavní strategický kontext pro vývoj i pro AI asistenty – při každém významném milníku ho aktualizujte (odškrtávání úkolů, doplnění zjištění). Dokument **nenahrazuje** `database_schema.md` ani technické migrace; doplňuje je produktovým a architektonickým směrem.  
**Zásady:** Multi-tenant izolace dat (`tenant_id`, RLS), offline-first u worker vrstvy (Drift, UTC, timestamp merging), Riverpod, i18n bez hardcoded textů v UI.

---

## Metodologie a limity analýzy

- **Kódová základna:** Flutter/Dart, Riverpod, GoRouter; admin a super_admin často **Supabase přímo** přes repozitáře a streamy; worker na mobilu **Drift + synchronizace + fronta mutací**.
- **Multi-tenant v aplikaci:** `SupabaseService.safeFrom` / `safeInsertPayload` vynucují `tenant_id` na klientovi („Frontend Firewall“); **skutečná izolace** musí být dorovnána **RLS na serveru** (ověření v SQL migracích / Supabase Dashboard).
- **Co tento dokument automaticky neověřuje:** kompletní mapa všech dotazů mimo `safeFrom`, Edge Functions, cron, a chování při impersonaci super admina v produkci.

---

## 1. Super-Admin portál

### A. Současný stav

- **Přehled tenantů:** dashboard (`super_admin_dashboard`), seznam tenantů, vyhledávání, základní metriky (MRR apod. přes providery).
- **Detail tenanta:** `tenant_detail_screen` — profily, moduly, statistiky, export dat, onboarding wizard, impersonace.
- **Audit log:** `audit_log_screen` + sdílené helpery; čtení z `audit_logs` (závisí na RLS pro super admina).
- **HQ / interní tým:** obrazovky a providery pro HQ staff, smlouvy, absence, agency settlements.
- **Support interventions:** evidence zásahů podpory.
- **Billing / exporty:** modaly a akce nad fakturací/exporty (souvislosti se Stripe a tenant moduly).

### B. Mezery (gaps)

- **Konzistence UX:** různé modaly vs. jednotný „HQ design system“ (spacing, empty states, chybové stavy).
- **Observabilita:** slabší propojení „co se stalo v tenantovi“ ↔ audit ↔ support intervention (ruční skok mezi obrazovkami).
- **i18n:** většina klíčů pod `super_admin.*`; riziko výpadků u novějších dialogů — systematický průchod včetně ES.
- **Bezpečnostní review:** impersonace a export dat vyžadují jasný provozní proces (logování, TTL, dokumentace).

### C. Návrh vylepšení

- **Jednotná karta tenanta:** sjednotit akce (export, wizard, impersonate, billing) do předvídatelného layoutu a navigace.
- **Propojení audit ↔ tenant:** filtr auditu podle `tenant_id` přímo z detailu tenanta (deep link / předvyplněný filtr).
- **Metriky:** srozumitelné definice MRR/ARPU v UI (tooltip + odkaz na interní dokumentaci), aby se předešlo interpretačním chybám.
- **QA i18n:** průchod `super_admin` + `common` klíčů ve všech podporovaných jazycích.

---

## 2. Admin portál (dispečink)

### A. Současný stav

- **Úkoly:** Kanban (`admin_tasks_screen`), streamy, drag-and-drop změna stavu, automatizace (`automatic_tasks`), checklisty (šablony + instance u úkolu), komunikace (šablony, WhatsApp).
- **Rezervace:** Kanban, formuláře, služby na úrovni rezervace / bytu / katalogu (override pattern).
- **Finance:** hotovostní peněženky, transakce, billing snapshots, settlements, provize / výplaty, reporty.
- **Kalendář:** plánovací kalendář (úkoly + rezervace).
- **Klienti / apartmány / tým:** CRM, stav apartmánů, absence, iCal zdroje.
- **Automatizace:** pravidla, fronta, log (napojení na příslušné tabulky v DB).

### B. Mezery (gaps)

- **Offline-first u admina:** primárně **online** Supabase; při výpadku sítě je zážitek křehčí než u workera (u webu očekávatelné; mobilní admin může trpět více).
- **Propojení modulů:** skoky mezi úkolem ↔ rezervací ↔ klientem ↔ fakturací nejsou všude stejně rychlé a konzistentní.
- **Hromadné akce:** částečně pokryty podle scénáře; filtrování a dávkové operace by šly sjednotit a rozšířit tam, kde to dává smysl.
- **i18n / technický dluh:** velké soubory (např. `admin_tasks_screen`) zvyšují riziko regrese při překladech; občas je potřeba dohledat místa bez `.tr()`.
- **RLS vs. klient:** závislost na důsledném použití `safeFrom`; jakékoli `.from()` bez obalu na tenant tabulkách = riziko (code review checklist).

### C. Návrh vylepšení

- **Cross-linking:** z karty úkolu stabilní akce „otevřít rezervaci“, „otevřít apartmán“, „otevřít klienta“ tam, kde existuje FK.
- **Filtry a uložené pohledy:** uložené filtry dispečera (např. „dnes + můj tým“) přes lokální preference uživatele (bez nového produktového modulu).
- **Admin na mobilu:** pokud je cíl použití v terénu — zvážit read-only cache nebo zjednodušené chování pro kritické seznamy (aditivně).
- **Statická kontrola:** skript nebo CI kontrola zakázaných vzorů (`supabase.from` bez `safeFrom` u tabulek s `tenant_id`).

---

## 3. Worker portál (mobil)

### A. Současný stav

- **Drift (SQLite):** úkoly, apartmány, klienti, rezervace, tenant (měna), šablony zpráv, checklisty, pending mutace.
- **Synchronizace:** `WorkerSyncService` (mobile) — pull v časovém okně, push pending, synchronizace měny a šablon; web/stub varianty.
- **Offline:** `DriftMutationQueueService` a procesory pro dokončení s fotkou, hotovost, issue úlohy apod.
- **UI:** dashboard úkolů, detail typů úkolů, checklisty, hotovost, výdělky, absence.
- **Timestamp merging:** dokumentováno u `tasks.updated_at`; logika konfliktů / smart merge ve worker sync vrstvě.

### B. Mezery (gaps)

- **Parita polí:** nové sloupce na serveru musí být konzistentně v selectech Drift sync a modelech (jinak prázdný kontext offline).
- **Šířka sync okna:** pevné okno dnů dopředu/dozadu — edge cases (dlouho dopředu naplánované úkoly) mohou chybět v lokální DB.
- **Stav synchronizace:** uživatel potřebuje jasnější feedback „co čeká na odeslání“ (fronta mutací).
- **Web worker:** stub nebo omezená funkce vs. mobil — sjednocení očekávání v UI (např. banner „na webu pouze online“).

### C. Návrh vylepšení

- **Checklist pro vývojáře:** při každé migraci `tasks` / `apartments` / … ověřit drift mapování + worker select.
- **Nastavitelné nebo dynamické okno sync** (konfigurace tenanta / role) v rámci stávajícího sync modulu.
- [x] **Obrazovka „Fronta offline“** — `WorkerMutationQueueScreen` (`/worker/mutation-queue`), `pendingMutationsProvider`, žlutý banner na dashboardu otevírá seznam.
- **Lepší empty / chybové stavy** při `syncInProgress` / offline (bez nových backendů).

---

## 4. Klientský portál (majitelé)

### A. Současný stav

- **Layout:** `owner_layout` — dashboard, apartmány, detail apartmánu, rezervace (Kanban s omezeními editace), úkoly (read-only Kanban), plánovací kalendář, billing snapshots.
- **Dialogy:** hlášení závad, detail úkolu (read-only nebo omezené akce).
- **Data:** providery nad Supabase s omezením podle role majitele a vazeb klient–profil (RLS musí držet stejnou hranici).

### B. Mezery (gaps)

- **Hosté vs. majitelé:** produktově rozlišit, co případný „host“ vidí — v kódu je důraz na **majitele** (CRM přes `clients.profile_id`); samostatná role hosta může být nejasná.
- **Blokace kalendáře:** sloupec `is_owner_block` ve schématu — ověřit plné propojení ve všech relevantních pohledech kalendáře a rezervací.
- **Notifikace / komunikace:** majitel může mít menší přehled než dispečink — dotažení textů a kanálů tam, kde je to v produktu žádoucí.
- **i18n:** owner sekce musí držet krok s klíči `owner.*`.

### C. Návrh vylepšení

- **Jasné copy a i18n** pro roli majitele (co smí / nesmí) na kritických obrazovkách.
- **Jednotný nápovědný blok (FAQ)** u rezervací a úkolů — snížení dotazů na podporu.
- **Vizuální odlišení** owner blokace vs. běžné rezervace ve všech kalendářích.
- **Propojení billing snapshots** s jednoduchým vysvětlením položek (rozbalitelný souhrn bez nového modulu).

---

## Průřezová architektura

### Multi-tenant a RLS

- **V aplikaci:** silný vzor `SupabaseService.safeFrom` + `safeInsertPayload`.
- **Riziko:** jakákoli cesta mimo tento vzor nebo chybný `tenantIdForData` (např. při impersonaci) může vést k úniku dat nebo prázdným výsledkům.
- **Doporučení:** periodický audit migrací RLS + automatizovaný grep + manuální test impersonace.

### Offline-first a UTC

- **Worker:** Drift + fronta + sync — odpovídá cíli offline-first.
- **Admin / Super admin / Owner:** prakticky **online-first**; je v pořádku, ale je třeba to komunikovat v UX a nepředpokládat offline chování tam, kde není implementováno.

### Riverpod a stav

- Dominantní **AsyncNotifier** / **StreamProvider** / **FutureProvider**; velké obrazovky používají **ConsumerStatefulWidget** (legitimní pro lokální kontrolery a dialogy).
- **Riziko:** velké `StatefulWidget` s mnoha lokálními stavy — duplicita s providery; postupné dělení na menší widgety bez změny business pravidel.

### i18n

- Projekt používá **easy_localization** a JSON; většina UI používá `.tr()`.
- **Riziko:** zbytky hardcoded řetězců, dynamické stringy mimo i18n, neúplné ES (nebo jiné jazyky).

---

## Roadmapa (prioritizovaně)

### Fáze 1 – Kritické: stabilizace a důvěra v data

- [x] **Audit RLS + `safeFrom`:** ověřit všechny tenant tabulky (finance, úkoly, rezervace, logy) — srovnání migrací s reálnými dotazy v aplikaci.
  - [x] Vytvořena SQL migrace pro fix RLS u `notifications` a `apartment_owners` (`20260330150000_fix_rls_notifications_and_owners.sql`).
  - [x] Refaktoring safeFrom v modulu Admin (Finance a Úkoly).
  - [x] Refaktoring safeFrom – zbývající Admin (tým, klienti, moduly, iCal, šablony, seedery), Worker sync/offline fronta a sdílené core služby (notifikace, audit, invite, zařízení).
  - [x] Finální dočištění: modul Communication (`tenant_message_templates`, denormalizace WhatsApp) + kontrola core/repositories (bez zbývajících holých `.from()` u tenant tabulek mimo záměrné výjimky).
- [x] **Worker sync / Drift parita:** zavedený checklist po každé DB změně (sloupce, selecty ve worker sync, Dart modely / mapování).
  - [x] Přidány kritické provozní sloupce (parkování, jazyk hosta, due_date) do Driftu a synchronizace.
  - [x] Zobrazení nových provozních dat (parkování, jazyk, blokace) ve Worker UI.
  - **2026-03-28:** Role Worker je plně Offline-first (včetně peněženky, absencí, výdělků a fotek v checklistech).
- [ ] **Impersonace a export (super admin):** bezpečnostní a provozní review + dostatečný audit trail v UI / logu.
- [ ] **i18n smoke test:** CS / EN / ES na kritických tocích (přihlášení, úkol, rezervace, owner billing).
- [x] **Chybové stavy offline (worker):** jasná uživatelská hláška při selhání push fronty (žádné tiché selhání).

### Fáze 2 – UX a propojení modulů

- [ ] **Admin cross-navigation:** úkol ↔ rezervace ↔ apartmán ↔ klient (konzistentní akce a odkazy).
- [ ] **Super admin:** propojit audit a detail tenanta (filtry, rychlé přepnutí kontextu).
- [ ] **Owner:** sjednotit zobrazení blokací a vysvětlující texty; doladit kalendář a rezervace.
- [ ] **Automatizace / komunikace:** sjednotit UX šablon (překlady, náhled, chybové stavy Twilio / WhatsApp).
- [ ] **Riverpod úklid:** u největších obrazovek extrahovat samostatné widgety a omezit zbytečný `setState`, kde to nesahá na business logiku.

### Fáze 3 – Pokročilé vylepšení stávajících modulů

- [ ] **Admin:** uložené filtry / pohledy dispečera; rozumné hromadné akce tam, kde dává smysl (vždy s auditem).
- [ ] **Worker:** konfigurovatelné okno sync nebo chytré doplnění při úkolu mimo aktuální okno.
- [ ] **Finance:** lepší vysvětlení agregací u settlements / billing (tooltips, rozpad položek).
- [ ] **Kalendář:** sjednocení barev a legend s Kanbanem a task categories (vizuální konzistence).
- [ ] **Super admin observabilita:** lehké indikátory zdraví (např. selhání automation queue) nad existujícími daty.

---

## Závěr

Aplikace má **silné jádro**: worker offline vrstva, admin real-time dispečink, super admin správu tenantů a owner read-heavy portál. Největší přínos přinese **důsledné dotažení izolace dat**, **parita offline synchronizace** a **propojení obrazovek** bez přidávání nových produktových modulů.

_Při dokončení úkolu roadmapy měňte `- [ ]` na `- [x]` a případně doplňte datum a krátkou poznámku pod sekcí._
