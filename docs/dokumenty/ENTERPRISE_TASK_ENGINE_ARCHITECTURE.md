# Enterprise Task Assignment Engine – architektonický plán

**Datum:** 2025-03-04  
**Kontext:** Kompletní revize jádra plánování; soubor `task_assignment_engine.dart` je explicitně odemčen pro úpravy. Žádná byznysová logika hardcoded v Dartu – vše z číselníků a DB tenanta. Zapojení priorit lokací (zón).

---

## Cíl

Implementovat pět pilířů v pipeline generování návrhů úkolů a v samotném enginu:

1. **Priorita úkolů (Task Priority)** – batch seřadit podle `task_categories.planning_priority` před smyčkou přiřazování.
2. **Filtrace rolí (Skill Matching)** – kandidáti pouze z `tenant_services.required_role`, bez hardcoded `task_type` v Dartu.
3. **Priorita lokací (Zone Priority)** – při řazení volných kandidátů primárně podle zónové priority (personál ↔ zóna z DB).
4. **Load balancing (Férovost)** – po zóně řadit podle denní zátěže; odstranit `shuffle()` před sortem.
5. **Anti-amnézie (State Management)** – jedna sdílená reference na `toInsert` v rámci batch generování.

---

## 1. Přehled současného stavu a napojení na DB

### 1.1 Tabulky a modely

| Zdroj | Tabulka | Klíčové sloupce pro engine | Provider / model |
|-------|---------|----------------------------|------------------|
| Číselník priorit úkolů | `task_categories` | `code`, `planning_priority` (integer, NOT NULL) | `taskCategoriesProvider` → `TaskCategoriesByCode` (mapa code → TaskCategoryModel) |
| Katalog služeb tenanta | `tenant_services` | `id`, `service_type`, `required_role`, `duration_minutes` | `tenantServicesProvider` → List<TenantServiceModel>, v provideru mapa `catalogById` |
| Zóny / lokace | `zones` | `id`, `name`, `tenant_id` | `zonesProvider` → List<ZoneRow> |
| Preference personálu vůči zónám | `profiles.zone_preferences` | JSONB: zone_id → priorita (1–5, -1 = blacklist) | V rámci `TeamMember.zonePreferences` (načteno v admin_team_provider) |
| Apartmány | `apartments` | `zone_id` (FK na zones) | apartmentById, apartment.zoneId |
| Úkoly | `tasks` | `task_type`, `service_id` (FK tenant_services), `assigned_to`, `scheduled_start`, `due_date` | tasksList / existingTasksRaw |

**Důležité vazby:**

- `tasks.task_type` a `tenant_services.service_type` používají hodnoty odpovídající `task_categories.code` (dokumentace DB).
- `tasks.service_id` → `tenant_services.id`; z toho plynou `required_role` a délka služby.
- `apartments.zone_id` → `zones.id`. Personál má `profiles.zone_preferences`: mapa `zone_id` → priorita (1 = nejraději, 2–5 = dojedu, -1 = nikdy).

### 1.2 Kde se co dnes bere

- **Generování z rezervací** (`generateSmartTasks`):  
  Služba z `apartment_services` + katalog → `_ServiceTrigger` (obsahuje `requiredRole` z katalogu). Kandidáti: `team.where(_hasRole(m, svc.requiredRole!))` nebo celý tým při `required_role` null/any. Řazení batch: `planningPriority` z `_getPlanningPriorityForTaskType` (mix DB + hardcoded fallback), pak back-to-back, pak taskDate. Jedna proměnná `toInsert`, předávána do každého volání engine, po každém volání `toInsert.add(...)`.

- **Generování scheduled** (`generateScheduledTasks`):  
  Podobně: služba z katalogu, `service.requiredRole`, jedna `toInsert`, předávána do engine.

- **Přepočet personálu** (`recalculateAssignees`):  
  Kandidáti podle **hardcoded** řetězců `task_type`: cleaning → cleaners, transfer → drivers, check_in/out → checkInOutCandidates, maintenance → maintainers, **else → všichni**. `toInsert` vždy `[]` (žádný batch insert). Select úkolů **neobsahuje** `service_id`.

- **Engine** (`task_assignment_engine.dart`):  
  Přijímá `candidates`, `taskStart`, `taskEnd`, `deadline`, `applyNightRest`, `existingTasksRaw`, `toInsert`, `zoneId`, `isSacredTask`. Overlap z existing + toInsert, pak `freeCandidates`; počty denní/týdenní z existing + toInsert; **shuffle()**; sort: přetížení, zóna, denní počet; vítěz = first. Hardcoded: `taskBlockDurationMinutes` s `serviceType.toLowerCase() == 'cleaning'`.

---

## 2. Pilíř 1 – Priorita úkolů (Task Priority)

### 2.1 Požadavek

Úkoly do enginu nesypat náhodně. Před spuštěním smyčky přiřazování seřadit celý batch podle `task_categories.planning_priority` (ASC): 1 = řešit jako první (např. transfery).

### 2.2 Kde to dělat

- **V provideru**, před smyčkou „FÁZE C“ (před `for (final c in candidates)`).
- Batch = seznam kandidátů úkolů (`_SmartTaskCandidate` v generateSmartTasks; v generateScheduledTasks jde o implicitní pořadí z cyklu přes scheduled services).

### 2.3 Konkrétní kroky

1. **generateSmartTasks**  
   - Už dnes: `planningPriority` v `_SmartTaskCandidate` a sort podle `planningPriority`, pak back-to-back, pak taskDate.  
   - **Změna:** `planningPriority` brát **výhradně** z `task_categories`:  
     - Při sestavování kandidátů: `planningPriority = categoriesByCode[effectiveTaskType.trim().toLowerCase()]?.planningPriority ?? 99`.  
   - **Odstranit** hardcoded fallback v `_getPlanningPriorityForTaskType` (celý `switch (code)`). Funkce bude: `categoriesByCode[code]?.planningPriority ?? 99`.  
   - Řazení batch nechat: 1) planning_priority ASC, 2) isBackToBackCleaning (true dříve), 3) taskDate.

2. **generateScheduledTasks**  
   - Nemá „batch kandidátů“ v jednom listu – jede se v cyklu přes `scheduledServices` a úkoly.  
   - Pokud chceme globální prioritu i mezi scheduled úkoly: nejdřív načíst všechny scheduled úkoly k vytvoření do seznamu, obohatit každý o `planning_priority` z `task_categories` podle `service.serviceType`, seřadit tento seznam podle `planning_priority` ASC, pak v tomto pořadí volat engine a přidávat do `toInsert`.  
   - Alternativa (jednodušší): nechat pořadí podle bytů/služeb, ale každý úkol mít při volání engine správně vyplněnou prioritu pro budoucí rozšíření; pro „batch order“ stačí implementovat řazení scheduled kandidátů podle planning_priority před smyčkou (viz níže).

3. **recalculateAssignees**  
   - Neprodukuje batch k vložení; úkoly bere z DB a pro každý volá engine. Priorita „který úkol řešit první“ by mohla být podle `planning_priority` z `task_categories` podle `task_type` – dobrovolné vylepšení (např. seřadit `limitedTasksToProcess` podle priority před smyčkou).

### 2.4 Data v provideru

- **Už máme:** `taskCategoriesProvider` (FutureProvider<TaskCategoriesByCode>), načtení v generateSmartTasks do `categoriesByCode`.  
- **Dotáhnout:** Zajistit, že při sestavování kandidátů (generateSmartTasks / generateScheduledTasks) se nikde nepoužívá fallback z `_getPlanningPriorityForTaskType` s `switch`; vše jen `categoriesByCode[code] ?? 99`.  
- **Konvence:** `task_categories.code` a `tenant_services.service_type` mají být sladěné (stejné hodnoty), aby jedna priorita platila pro typ úkolu i typ služby.

---

## 3. Pilíř 2 – Filtrace rolí (Skill Matching)

### 3.1 Požadavek

Konec hardcoded stringů typu `if task_type == 'cleaning'`. Kandidáti se mají filtrovat **primárně** podle `required_role` v `tenant_services`.

### 3.2 Kde se role bere

- **Generování z rezervací:** Služba je z katalogu (`_ServiceTrigger`), už tam je `requiredRole` z `tenant_services`. Kandidáti: `team.where((m) => _hasRole(m, svc.requiredRole!))` nebo celý tým při null/empty/any. **Změna:** Žádná – zdroj je už katalog. Jen sjednotit konvenci: hodnoty `required_role` odpovídají `profiles.roles` (cleaner, driver, maintenance, checkin_agent); „any“ nebo prázdné = všichni s `assignableId(m).isNotEmpty`.

- **Generování scheduled:** Stejně – `service.requiredRole` z katalogu. Beze změny zdroje.

- **Přepočet personálu:** Dnes kandidáti podle `task_type` (cleaning, transfer, …) + else všichni. **Změna:** Role určit z DB:
  1. Úkol má `service_id` → vzít `catalogById[service_id]?.requiredRole`.  
  2. Pokud chybí nebo úkol nemá `service_id`: najít v katalogu první službu, kde `service_type` (normalizovaný) odpovídá `task_type` úkolu → použít její `required_role`.  
  3. Pokud ani tak nic → považovat za „any“ → kandidáti = všichni assignable (bez filtru podle role).  
  Filtrování: `team.where((m) => _hasRole(m, requiredRole))` pro konkrétní roli, jinak celý tým. **Žádný** switch/case nad `task_type` pro výběr role.

### 3.3 Konkrétní kroky v provideru

1. **recalculateAssignees**  
   - V selectu úkolů **přidat** sloupec `service_id`:  
     `.select('id, apartment_id, reservation_id, title, due_date, scheduled_start, assigned_to, task_type, status, service_id')`.  
   - Na začátku metody načíst katalog: `final catalog = await ref.read(tenantServicesProvider.future);` a `catalogById = {for (final s in catalog) s.id: s}`.  
   - Pro každý úkol:  
     - `requiredRole = map['service_id'] != null ? catalogById[map['service_id']]?.requiredRole : null`;  
     - pokud `requiredRole == null` nebo prázdné: `requiredRole = catalog.firstWhere((s) => s.serviceType.trim().toLowerCase() == taskType, orElse: () => null)?.requiredRole` – nebo bezpečněji projít catalog a najít první s `service_type == task_type`.  
   - Sestavit kandidáty:  
     - pokud `requiredRole == null` nebo prázdné nebo `'any'`: `candidates = team.where((m) => assignableId(m).isNotEmpty).toList()`;  
     - jinak: `candidates = team.where((m) => _hasRole(m, requiredRole)).toList()`.  
   - **Odstranit** celý blok `if (isCleaning) ... else if (isTransfer) ... else if (isCheckIn...) ... else if (isMaintenance) ... else checkInOutCandidates`.

2. **Generování (rezervace + scheduled)**  
   - Už používají `svc.requiredRole` / `service.requiredRole` z katalogu. Zkontrolovat, že nikde není doplňková hardcoded podmínka nad názvem služby nebo task_type (např. „prádelna“ → driver). Pokud tenant chce „Prádelna“ jen pro řidiče, nastaví v katalogu u služby Prádelna `required_role = driver`.

### 3.4 Engine

- Engine **nemá** znát role ani task_type. Dostane už vyfiltrovaný seznam `candidates`. Žádné změny v engine pro role.

---

## 4. Pilíř 3 – Priorita lokací (Zone Priority)

### 4.1 Požadavek

Při řazení volných kandidátů **primárně** hledat člověka s nejvyšší prioritou pro zónu daného apartmánu (nejnižší číslo, např. 1 = hlavní delegát pro tuto oblast). Data už v DB: `profiles.zone_preferences` (JSONB), načtená do `TeamMember.zonePreferences`.

### 4.2 Současný stav

- Engine dostává `zoneId` (apartment.zoneId).  
- `zonePreferencePriority(TeamMember m, String? zoneId)` vrací 1–5 nebo 99 (chybí = 99).  
- V sortu engine je pořadí: (1) vyloučit přetížené, (2) zóna, (3) denní počet.  
- **Problém:** Před sortem je **shuffle()**, takže efekt „primárně zóna“ je oslabený.

### 4.3 Změny v engine

1. **Odstranit** `freeCandidates.shuffle()`.  
2. **Pořadí sortu** změnit na striktně:
   - **Primární:** zónová priorita (asc) – `zonePreferencePriority(a, zoneId).compareTo(zonePreferencePriority(b, zoneId))`.  
   - **Sekundární:** denní počet úkolů (asc) – kdo má v daný den méně úkolů, má přednost.  
   - **Volitelně terciární:** týdenní počet nebo stabilní tie-break (např. id) pro determinismus.  
3. Přetížení (maxDailyAllowed / maxWeeklyAllowed): buď ponechat jako filtr (vyřadit z freeCandidates ty nad limitem) před sortem, nebo nechat v sortu jako první kriterium „nepřetížení před přetížené“. Doporučení: ponechat v sortu první kriterium „nepřetížení před přetížené“, pak zóna, pak denní počet – aby se neposílali úkoly lidem už přes limit.

**Výsledné pořadí sortu (v engine):**

1. Nepřetížení před přetížené (isOverA / isOverB).  
2. Zóna: nižší číslo = dříve (zoneA.compareTo(zoneB)).  
3. Denní počet: nižší = dříve (dCountA.compareTo(dCountB)).  
4. (Volitelně) Týdenní počet nebo assignableId pro stabilitu.

Bez shuffle.

### 4.4 Provider

- `_filterAndSortByZonePreferences` už v provideru filtruje blacklist (-1) a řadí podle zóny. Používá se před voláním engine. Engine pak znovu řadí uvnitř `freeCandidates`. Po úpravě engine bude jediný „autoritativní“ řazení uvnitř engine (zóna → zátěž); předání kandidátů může zůstat v libovolném pořadí, protože engine je přeřadí. Blacklist (-1) musí zůstat v provideru – engine nedostane takové kandidáty, protože provider je vyfiltruje.

---

## 5. Pilíř 4 – Load balancing (Férovost)

### 5.1 Požadavek

Po zohlednění zóny má přijít na řadu zátěž: pokud mají dva lidé stejnou prioritu zóny, úkol dostane ten, kdo má v daný den **méně** úkolů. Odstranit nesmyslné plošné `shuffle()` před sortováním.

### 5.2 Změny v engine

- **Odstranit** volání `freeCandidates.shuffle()`.  
- Sort viz výše: přetížení, zóna, **denní počet** (asc).  
- Denní a týdenní počty se berou z `existingTasksRaw` a z **toInsert** – to už engine dělá; tím pádem „virtuální“ úkoly z aktuálního batch se započítají a další úkol v pořadí uvidí aktuální zátěž.

Žádné další změny; logika počtů zůstává.

---

## 6. Pilíř 5 – Anti-amnézie (State Management)

### 6.1 Požadavek

Při iteraci úkolů engine musí striktně používat **jednu sdílenou** referenci na list `toInsert`, aby ihned věděl o úkolech přiřazených o milisekundu dříve.

### 6.2 Současný stav

- **generateSmartTasks:** Jedna proměnná `final toInsert = <Map<String, dynamic>>[];`, v cyklu `for (final c in candidates)` se volá `pickAssigneeWithCollisionAvoidance(..., toInsert: toInsert)` a hned potom `toInsert.add({...})`. **Správně.**  
- **generateScheduledTasks:** Jedna proměnná `final toInsert = <Map<String, dynamic>>[];`, v cyklu volání engine s `toInsert: toInsert` a `toInsert.add({...})`. **Správně.**  
- **recalculateAssignees:** Volá engine s `toInsert: []` – zde se nevkládá batch, každý úkol je samostatný návrh změny. **Záměrně** prázdný list; není to „amnézie“, ale jiný use-case.

### 6.3 Kroky

1. **Nepřerušovat** sdílenou referenci: v obou generátorech nikdy nevytvářet nový list uvnitř smyčky ani nepassovat jiný list než ten, do kterého se hned po návratu z engine přidá záznam.  
2. **Dokumentovat** v kódu (komentář u `toInsert` a u volání engine): „Batch generování vyžaduje jednu sdílenou referenci na toInsert; po každém volání engine musí volající přidat nový záznam do toInsert.“  
3. **Kontrakt engine:** Parametr `toInsert` je „in/out“ v tom smyslu, že engine pouze čte; volající je povinen po každém přiřazení do stejného listu přidat payload nového úkolu (včetně `assigned_to`, `scheduled_start`, `due_date`), aby další volání engine v rámci téhož batch vidělo tento úkol při kontrole překryvu a při výpočtu denních/týdenních počtů.

Žádná změna signatury engine; pouze garance použití a dokumentace.

---

## 7. Engine – souhrn změn v `task_assignment_engine.dart`

1. **Odstranit** `freeCandidates.shuffle()`.  
2. **Změnit pořadí sortu** u `freeCandidates` na:
   - nejdříve vyloučit přetížené (isOverA / isOverB) – přetížení až za nepřetížené;
   - pak **zóna** (asc): `zonePreferencePriority(a, zoneId).compareTo(zonePreferencePriority(b, zoneId))`;
   - pak **denní počet** (asc): `dCountA.compareTo(dCountB)`;
   - volitelně tie-break (týdenní počet nebo id).  
3. **Hardcoded cleaning v taskBlockDurationMinutes:**  
   - Varianta A: Nechat v engine, ale učinit závislým na parametru (např. `addApartmentCleaningBuffer: bool`) předaným z provideru; provider nastaví true jen pro služby, u kterých to vyplývá z katalogu (např. service_type odpovídá kategorii s určitým kódem).  
   - Varianta B (čistší): Z engine **odstranit** `taskBlockDurationMinutes` a předávat do engine už **vypočtenou délku v minutách** (provider spočítá duration z katalogu + bytu a předá `taskEnd = taskStart + duration`). Pak engine nepotřebuje znát `serviceType` ani „cleaning“.  
   - Doporučení: **Varianta B** – engine přijímá `taskStart`, `taskEnd` (nebo `durationMinutes`), overlap a zátěž řeší bez znalosti typů služeb.  
4. **applyNightRest / isSacredTask:** Zůstávají jako boolean parametry z provideru; provider je určí z katalogu / task_categories (např. podle kategorie nebo služby), bez hardcoded stringů v engine.  
5. Odstranit záhlaví „LOCKED“ a upravit komentáře tak, aby odrážely nová pravidla (zóna první, pak zátěž, bez shuffle, žádná byznysová logika podle task_type uvnitř engine).

---

## 8. Provider – souhrn změn

### 8.1 admin_tasks_provider.dart

- **Planning priority:**  
  - `_getPlanningPriorityForTaskType`: odstranit celý `switch (code)` fallback; vracet jen `categoriesByCode[code]?.planningPriority ?? 99`.  
  - Ujistit se, že generateSmartTasks používá pouze tuto funkci s `categoriesByCode` naplněným z `taskCategoriesProvider`.  
  - generateScheduledTasks: pokud chceme řazení scheduled úkolů podle priority, sestavit nejdřív seznam „scheduled candidates“ s `planning_priority` z `task_categories` podle `service.serviceType`, seřadit podle `planning_priority` ASC, pak v tomto pořadí volat engine a přidávat do `toInsert`.

- **Role (recalculateAssignees):**  
  - Do selectu úkolů přidat `service_id`.  
  - Načíst katalog (tenant_services).  
  - Pro každý úkol určit `requiredRole` z catalogById[service_id] nebo první služba s service_type == task_type; jinak any.  
  - Kandidáti pouze podle `required_role` (a dostupnosti, smlouvě, blacklistu zón); **odstranit** všechny větve `isCleaning`, `isTransfer`, `isCheckIn`, `isCheckOut`, `isMaintenance`, `else`.

- **toInsert:**  
  - V generateSmartTasks a generateScheduledTasks ponechat jednu sdílenou `toInsert` a doplnit komentáře o kontraktu.

- **Duration / sacred / night rest:**  
  - Pokud engine nebude mít `taskBlockDurationMinutes`, provider bude počítat délku sám (už částečně dělá) a předávat taskStart/taskEnd. Sacred a night rest určit z kategorie/služby (např. z task_categories nebo z konvence service_type) a předat jako bool.

### 8.2 task_assignment_engine.dart

- Odstranit shuffle.  
- Sort: přetížení → zóna → denní počet.  
- Volitelně: odstranit `taskBlockDurationMinutes` z engine a přijímat jen časy/délku; zbytek v provideru.

---

## 9. Clean Architecture a Riverpod

- **Engine** = čistá doménová vrstva: funkce bez async, bez Riverpod, bez přímého volání Supabase. Vstupy: seznam kandidátů, časy, existingTasksRaw, toInsert, zoneId, příznaky. Výstup: (assignTo, start, end).  
- **Provider** = aplikační vrstva: načítá data (tasks, task_categories, tenant_services, team, absences, apartments), sestavuje batch, řadí podle planning_priority, filtruje kandidáty podle role a zón, volá engine v cyklu, zapisuje do DB (nebo fronty mutací).  
- **Data:** Číselníky a tenant data přes stávající providery (`taskCategoriesProvider`, `tenantServicesProvider`, `teamFullListProvider`, `apartmentsFullListProvider`, …). Žádná nová tabulka; pouze rozšíření selectu (service_id u tasks) a konzistentní použití stávajících sloupců.

---

## 10. Pořadí implementace (doporučené)

1. **Engine:** Odstranit shuffle, upravit sort (zóna → denní počet), doplnit komentáře; volitelně vyčíst duration z parametrů.  
2. **Provider – planning:** Odstranit hardcoded fallback v _getPlanningPriorityForTaskType; ověřit řazení batch podle categoriesByCode.  
3. **Provider – role (recalculate):** Přidat service_id do selectu, načíst katalog, sestavit requiredRole z DB, odstranit větvení podle task_type.  
4. **Provider – scheduled:** Pokud plánujeme řazení scheduled podle priority, sestavit seznam kandidátů s planning_priority a seřadit před smyčkou.  
5. **Dokumentace:** Krátký komentář u toInsert a u volání engine o kontraktu batch + toInsert.  
6. **Testy / manuální kontrola:** Batch s více úkoly ve stejném čase → jeden člověk nesmí dostat dva; úkol „Prádelna“ s required_role=driver → pouze řidiči; řazení podle zóny a zátěže bez náhodného shuffle.

Tím je architektura připravena na implementaci bez hardcoded byznysové logiky v Dartu a s plným napojením na `task_categories`, `tenant_services` a `zone_preferences`.
