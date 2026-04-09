# FalcoNest – globální hloubkový audit ekosystému

**Datum:** 2026-03-05  
**Rozsah:** super_admin (HQ), admin (Web/Tablet), worker (Mobil), core, shared, services, providery.  
**Pravidla:** Žádné automatické opravy – pouze report.

---

## Přehled pilířů

| Pilíř | Stav | Poznámka |
|-------|------|----------|
| **super_admin** | Implementován | HQ centrála, Account Managery, RLS a route guard po auditu v pořádku. |
| **admin** | Implementován | Web/Tablet pro úklidové agentury, rozsáhlé obrazovky (úkoly, rezervace, byty, finance, tým). |
| **worker** | Implementován | Mobilní aplikace pro terénní pracovníky; offline-first přes **Drift (SQLite)**, Isar byl odstraněn. |
| **core / shared** | Aktivní | Auth, router, offline fronta, Drift repozitáře, Supabase služby. |

---

# KRITICKÉ

## 1. Multi-tenant a bezpečnost (Supabase & RLS)

### 1.1 Propisování tenant_id v admin a worker

- **Admin:** Dotazy do Supabase v providerech a repozitářích používají `tenant_id` z `authNotifierProvider` (resp. `tenantIdForData`). Kontrolované soubory: `reports_provider.dart`, `planning_calendar_provider.dart`, `finance_billing_provider.dart`, `admin_tasks_provider.dart`, `clients_provider.dart`, `apartments_provider.dart` – všude je buď `.eq('tenant_id', tenantId)`, nebo filtrace přes `apartment_id` / rezervace v rámci tenanta. **Žádný select bez vazby na tenanta nebyl nalezen.**
- **Worker:** `worker_sync_service_mobile.dart` vždy předává `tenantId` a používá `.eq('tenant_id', tenantId)` u tasks; apartments/reservations/clients se stahují přes `inFilter('id', ...)` z již vyfiltrovaných úkolů. Push updates používá `.eq('id', supabaseId)`; u tasks RLS na straně Supabase omezí řádky podle tenanta. U rezervací je explicitně `.eq('tenant_id', tenantId)`.
- **Owner (klientský portál):** `owner_planning_calendar_provider.dart` nestahuje úkoly podle `tenant_id`, ale podle `.inFilter('apartment_id', ownedApartmentIds)`. Bytové ID pocházejí z `ownerApartmentsProvider`, který je vázaný na přihlášeného majitele (RLS a vazba na profil). **Bezpečné za předpokladu, že RLS na tasks a apartments je správně nastavené.**

### 1.2 RLS v databázi

- V migracích je velké množství politik (tenants, profiles, apartments, tasks, reservations, clients, finance, settlements, support_interventions, agency_management_settlements atd.). Politiky používají `my_tenant_id()`, `is_super_admin()`, u account_managera byla přidána podmínka pro `tenants_select` (migrace 20260306000000).
- **Doporučení:** Před produkčním nasazením provést ruční nebo automatizovaný test RLS (např. přihlášení pod různými rolemi a ověření, že nelze číst/měnit data cizího tenanta). V kódu nebyla nalezena záměrná „díra“ (select bez tenant filtru).

### 1.3 Super-admin a globální tabulky

- `tenant_command_modal.dart` a `super_admin_service.dart` volají `.from('tenants').update(...).eq('id', tenantId)`. To je oprávněné pro HQ; RLS pro tenants po opravě povoluje super_admin vše. **V pořádku.**

---

## 2. Offline-first architektura (worker)

### 2.1 Lokální databáze

- **Isar byl odstraněn.** Komentáře v kódu uvádějí nestabilitu na iOS („Collection id is invalid“). Jako náhrada se používá **Drift (SQLite)**.
- `lib/core/database/drift/` obsahuje `app_database.dart`, `database_provider.dart` a repozitáře: tasks, apartments, clients, reservations, pending_mutation, pending_audit_action, message_template, tenant. Worker čte a zapisuje přes `DriftTaskRepository` a související repozitáře.
- **Závěr:** Lokální databáze pro worker je implementována (Drift). Čtení v terénu bez internetu je možné z SQLite.

### 2.2 Synchronizace na pozadí

- `WorkerSyncService` (mobilní varianta) stahuje úkoly, byty, rezervace, klienty a šablony zpráv z Supabase s filtrem `tenant_id` a přiřazením workerovi. Data se zapisují do Drift. Při návratu online se volá `pushPendingUpdates` (úkoly) a `pushPendingReservationUpdates` (rezervace).
- Fronta mutací: `DriftMutationQueueService` zapisuje do `DriftPendingMutationRepository`; při přechodu offline→online zpracuje frontu (úkoly, hotovost, fotky, firemní výdaje, issue úkoly). **Synchronizace na pozadí je implementována.**

### 2.3 Timestamp Merging a řešení konfliktů

- V `drift_task_repository.dart` je komentář „Sestavení merged metadata pro Timestamp Merging“ při aktualizaci úkolu (merge metadata overlay s existujícími). Samotné **řešení konfliktů na úrovni „kdo má novější updated_at“ (např. porovnání UTC časových razítek před zápisem do Supabase a rozhodnutí merge / reject)** v kódu **není explicitně implementované**. Sync funguje jako „push pending“ – lokální změny se po řadě odesílají; při kolizi (např. současná změna na serveru) by záviselo na chování Supabase (poslední update vyhrává). **Doporučení:** Zdokumentovat nebo doplnit strategii konfliktů (např. last-write-wins s `updated_at` nebo jednoduché merge pravidel) a případně přidat kontrolu časových razítek před overwrite.

---

# VAROVÁNÍ

## 3. I18n a lokalizace

### 3.1 Hardcodované texty v UI (bez .tr())

- **worker (Worker dashboard):**  
  `lib/features/worker/screens/worker_dashboard_screen.dart` – v dialogu výběru jazyka:  
  `const Text('Čeština')`, `const Text('English')`, `const Text('Español')`.  
  **Mělo by být:** např. `Text('common.language_cs'.tr())` a odpovídající klíče v cs/en/es.

- **admin (Apartments):**  
  `lib/features/admin/admin_apartments_screen.dart` –  
  `hintText: 'SUN-01'` (příklad kódu bytu) na dvou místech (řádky cca 1146, 1849).  
  **Doporučení:** Přesunout do i18n (např. `admin.apartments_code_hint` s hodnotou „SUN-01“ nebo obecný placeholder).

- **admin (Tasks):**  
  `lib/features/admin/admin_tasks_screen.dart` –  
  `hintText: '0'` na více místech (např. řádky 2402, 2501, 3731).  
  Jde o číselný placeholder; pro konzistenci lze použít společný klíč (např. `common.zero_placeholder`).

- **worker (Cash collection):**  
  `lib/features/worker/utils/cash_collection_dialog.dart` –  
  `hintText: '0'`.  
  Stejné doporučení jako u admin tasks.

- **settings (Service editor):**  
  `lib/features/settings/service_editor_dialog.dart` –  
  `hintText: '60'` (řádek cca 304).  
  **Doporučení:** i18n klíč pro výchozí délku služby (např. `settings.service_duration_minutes_hint`).

- **owner (Planning calendar):**  
  `lib/features/owner/providers/owner_planning_calendar_provider.dart` –  
  `String aptName = 'Neznámý';` a později `aptName == 'Neznámý' ? null : aptName`.  
  **Doporučení:** Použít lokalizovaný fallback (např. `common.unknown`.tr()) nebo konstantu z i18n.

- **finance (Billing):**  
  `lib/features/admin/providers/finance_billing_provider.dart` –  
  Fallback název snapshotu: `'Neznámý'`.  
  **Doporučení:** i18n klíč pro „neznámý“.

- **calendar (Planning task type):**  
  `lib/features/owner/providers/owner_planning_calendar_provider.dart` –  
  `taskType: (map['task_type']?.toString() ?? 'Jiné').trim()`.  
  **Doporučení:** Fallback „Jiné“ přes i18n.

- **super_admin (Billing modal):**  
  `lib/features/super_admin/super_admin_billing_modal.dart` –  
  `Text('0', style: ...)` (řádek cca 431).  
  **Doporučení:** Buď konstantní „0“, nebo klíč typu `common.zero`.

- **Drift task repository (status):**  
  `lib/core/database/drift/repositories/drift_task_repository.dart` –  
  Porovnání statusů s řetězci `'dokončeno'`, `'hotovo'`, `'nový'`, `'new'` atd.  
  **Poznámka:** Jde o interní logiku filtru; pokud jsou statusy v DB vždy v angličtině, může být rozpor s lokalizovanými hodnotami. Zkontrolovat konzistenci s tabulkou task statusů a případně sjednotit na kódy (např. `completed`, `pending`) místo lokalizovaných slov.

### 3.2 Shrnutí i18n

- Většina UI textů v admin, super_admin a worker používá `.tr()` a klíče z JSON.  
- **Varování:** Jazykové názvy v worker draweru (Čeština, English, Español), příklady placeholderů (SUN-01, 60, 0) a fallbacky (Neznámý, Jiné) by měly projít i18n pro konzistenci a snadné překlady.

---

## 4. State management a Clean Architecture (Riverpod)

### 4.1 Oddělení logiky od UI

- Byznysová logika je většinou v providerech a repozitářích; obrazovky volají `ref.watch` / `ref.read`. Výjimkou jsou velké obrazovky (např. `admin_apartments_screen.dart`, `admin_tasks_screen.dart`), kde je část logiky (validace, formátování) přímo ve widgetu. **Doporučení:** Postupně přesouvat složitější logiku do providerů nebo služeb.

### 4.2 autoDispose a memory leaky

- Řada `FutureProvider.family` a podobných providerů **nemá** `autoDispose` (např. řada providerů v admin, calendar, owner). U providerů vázaných na obrazovku nebo na parametr (např. tenant ID, měsíc) by bylo vhodné zvážit `autoDispose`, aby se po opuštění obrazovky data uvolnila.  
- V super_admin byly po auditu přidány `autoDispose` u `tenantDetailProvider` a `monthlyAgencySettlementsProvider`. **Doporučení:** Projít providery v admin a worker a u těch, které slouží jen konkrétní obrazovce nebo modálu, zvážit `autoDispose`.

### 4.3 Controllery a dispose

- U kontrolovaných StatefulWidgetů (issue_reporter_dialog, template_editor_dialog, pin_verify_screen, login_screen, update_password_screen) jsou `TextEditingController` a podobné controllery v `dispose()` uvolňovány. **Žádný zjevný memory leak u controllerů nebyl nalezen.**

---

## 5. Kvalita kódu a české komentáře

### 5.1 Mrtvý kód a nepoužívané soubory

- **Neprováděna plná automatická analýza** (např. `dart analyze` nebo dead code detector). Doporučení: spustit `dart analyze` a `flutter analyze` na celý projekt a odstranit nepoužívané importy a mrtvé proměnné.  
- Některé soubory jsou označeny jako stub nebo no-op (např. `worker_sync_service_web.dart` – „no-op, žádný Isar“; `database_init_stub.dart`). To je záměr pro rozdělení web vs. mobil.

### 5.2 České komentáře (PROČ)

- V repozitářích a offline službách (Drift, mutation queue, sync, cash, photo task, issue task, company expense) jsou české komentáře vysvětlující PROČ (např. fronta mutací, offline záchrana hotovosti, přepojení z Isaru na Drift).  
- U složitějších providerů (reports, finance_billing, planning_calendar) jsou také komentáře. **Doporučení:** U nových složitých funkcí zachovat stejnou úroveň (český komentář PROČ).

---

# DOPORUČENÍ

## 6. RLS a mobilní aplikace (worker)

- Worker používá stejný Supabase klient a stejné RLS politiky jako web. Předpokládá se, že JWT obsahuje správné claims a RLS je na serveru vynucováno. **Doporučení:** Ověřit v dokumentaci nebo testech, že role worker/cleaner/driver nemají přístup k tabulkám mimo svůj tenant a že politiky pro tasks, apartments, reservations, clients jsou pro mobilní klienty platné.

## 7. Sdílené složky (core, shared)

- **core:** Obsahuje auth, router, offline frontu, Drift, Supabase služby, část repozitářů. Struktura je přehledná.  
- **shared:** V projektu byl nalezen pouze `shared/.gitkeep` – složka je prázdná nebo téměř prázdná. **Doporučení:** Buď začít používat `shared` pro opravdu sdílené widgety/utilky, nebo to v dokumentaci explicitně uvést.

## 8. Přehled nálezů podle kritičnosti

| Priorita | Oblast | Nález |
|----------|--------|--------|
| Kritické | RLS | V Dart kódu nebyl nalezen select bez vazby na tenanta; doporučeno otestovat RLS ručně. |
| Kritické | Offline | Timestamp Merging – není explicitní conflict resolution (updated_at); doporučeno zdokumentovat/doplňovat. |
| Varování | i18n | Worker: „Čeština“, „English“, „Español“ v draweru. |
| Varování | i18n | Admin: hintText „SUN-01“, „0“; settings: „60“; owner/finance: „Neznámý“, „Jiné“; super_admin billing: „0“. |
| Varování | Riverpod | Řada providerů bez autoDispose; zvážit u obrazovkových/family providerů. |
| Doporučení | Kód | Spustit dart analyze; odstranit nepoužívané importy a mrtvý kód. |
| Doporučení | Architektura | Složitější logiku z velkých obrazovek postupně přesouvat do providerů/služeb. |
| Doporučení | shared | Složka shared je prázdná; rozhodnout o jejím využití. |

---

*Audit byl proveden prohlížením struktury projektu, grepem na tenant_id, Supabase dotazy, offline/sync kód, i18n vzory a vybrané providery a repozitáře. Žádná změna v kódu nebyla provedena.*
