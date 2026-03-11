# Hloubková analýza logiky přidělování úkolů (Task Assignment)

**Datum:** 2025-03-04  
**Kontext:** 4 kritické logické chyby odhalené zátěžovým testem zákazníka (screenshoty z produkce).  
**Pravidlo:** `task_assignment_engine.dart` je LOCKED – analýza a návrh oprav bez změny engine, pokud není explicitně povoleno.

---

## 1. Filtrování rolí (Skill Mismatch) – „Prádelna“ přiřazena uklízečce místo řidiče

### Kde se role aktuálně porovnávají

- **Při generování z rezervací** (`generateSmartTasks`):  
  Kandidáti se berou z **`svc.requiredRole`** (katalog `tenant_services.required_role` přes `_ServiceTrigger`).  
  - Pokud `requiredRole` je null / prázdný / `"any"` → `candidatesList = team` (všichni s `assignableId`).  
  - Jinak → `team.where((m) => _hasRole(m, svc.requiredRole!))`.  
  **Engine roli nekontroluje** – dostane už vyfiltrovaný seznam.

- **Při generování scheduled úkolů** (`generateScheduledTasks`):  
  Stejná logika: `service.requiredRole` z katalogu → filtr `_hasRole(m, service.requiredRole!)` nebo všichni.

- **Při přepočtu personálu** (`recalculateAssignees`):  
  Role se **neberou z katalogu**, ale **pouze z řetězce `task_type`** z DB:
  - `cleaning` / `úklid` → pouze **cleaners**
  - `transfer*` → pouze **drivers**
  - `check_in` / `check_out` → **checkInOutCandidates**
  - maintenance → **maintainers**
  - **Vše ostatní** (včetně „Prádelna“, „extra“, vlastní názvy služeb) → **`checkInOutCandidates`** = **všichni** personál s `assignableId(m).isNotEmpty` (celý tým kromě property_owner).

### Proč to propustilo uklízečku na „Prádelna“

1. **Přepočet:** Úkol s `task_type = "Prádelna"` (nebo „prádelna“, „extra“, apod.) nespadá pod žádný z výše uvedených klíčových slov → použit **else** → kandidáti = celý tým. Engine pak vybere jednoho (po shuffle + load-balance), klidně uklízečku.
2. **Generování:** Pokud má služba „Prádelna“ v katalogu `required_role = null` nebo `"any"`, při generování se také předají **všichni** jako kandidáti; engine opět může vybrat uklízečku.

**Závěr:**  
- Chyba není v engine (ten jen vybírá z předaných kandidátů).  
- Chyba je v **provideru**: (a) při přepočtu chybí mapování `task_type` → role a chybí použití `service_id` → katalog; (b) při generování záleží na tom, zda má služba v katalogu vyplněné `required_role`.

---

## 2. Udržení stavu (In-memory blokace) – Overbooking, „amnézie smyčky“

### Jak to dnes funguje

- **Generování z rezervací:**  
  Na začátku se načte `tasksList` z DB (jeden snapshot). Vytvoří se **jeden** seznam `toInsert = <Map<String, dynamic>>[]`.  
  V cyklu `for (final c in candidates)` se pro každý úkol volá `pickAssigneeWithCollisionAvoidance(..., existingTasksRaw: tasksList, toInsert: toInsert)` a **hned po návratu** se do `toInsert` přidá nový záznam (`toInsert.add({...})`).  
  Tedy **stejná reference** `toInsert` se předává do každého volání a průběžně roste – engine by měl „vidět“ už přiřazené virtuální úkoly.

- **Generování scheduled:**  
  Stejný vzor: jeden `tasksList`, jeden `toInsert`, v cyklu volání engine + `toInsert.add(...)`.

- **Přepočet personálu:**  
  Volá se `pickAssigneeWithCollisionAvoidance(..., toInsert: **[]** )` – vždy **prázdný** seznam. Přepočet neukládá dávku úkolů najednou, ale jen navrhuje změny, takže zde „amnézie“ v tomto smyslu nevzniká.

### Kde může vzniknout overbooking (3 úkoly na stejný čas pro jednoho člověka)

1. **Jiná cesta volání:**  
   Pokud existuje další volání generátoru (např. z jiného tlačítka / flow), které pro každý úkol vytvoří **nový** prázdný `toInsert`, pak engine v každém volání nevidí předchozí virtuální úkoly → může třikrát vybrat stejnou osobu pro stejný čas.

2. **Sdílení `tasksList` vs `toInsert` mezi více běhy:**  
   Pokud se „batch“ skládá z více samostatných volání (např. nejdřív rezervace, pak scheduled) a každé má vlastní `toInsert`, pak druhé volání nevidí úkoly z prvního, dokud nejsou v DB.

3. **Struktura dat:**  
   Engine očekává u položek v `toInsert` klíče `assigned_to`, `scheduled_start`, `due_date`. Pokud někde předáváme jinou strukturu (nebo jiné názvy), overlap pro virtuální úkoly se nenačte a kandidát zůstane „volný“.

4. **Časová zóna / parsování:**  
   `_parseTaskDateTimeUtc` v engine normalizuje na UTC. Pokud volající předává časy v lokále a bez konzistentního parsování, teoreticky může dojít k chybnému „žádný překryv“.

**Doporučení pro ověření:**  
- Ověřit, že **všechna** místa, která v jednom „batchi“ generují více úkolů, používají **jednu** sdílenou proměnnou `toInsert` a předávají ji do **každého** volání engine a po každém volání do ní přidávají záznam.  
- Zajistit, že žádná větev nevolá engine s čerstvě vytvořeným prázdným listem `[]` uvnitř smyčky.

---

## 3. Load balancing („hladový“ algoritmus)

### Aktuální chování v engine

- Po nalezení `freeCandidates` (bez časového překryvu) engine:
  1. Spočítá pro každého kandidáta **denní** a **týdenní** počet úkolů z `existingTasksRaw` a z `toInsert`.
  2. Nastaví limity: `maxDailyAllowed = minDaily + 2`, `maxWeeklyAllowed = minWeekly + 3`.
  3. **Nejdřív** zavolá `freeCandidates.shuffle()`.
  4. Pak seřadí: (1) nepřetížení před přetížené, (2) zónová preference, (3) `dCountA.compareTo(dCountB)` (nižší denní počet dříve).
  5. Vybere `freeCandidates.first`.

**Problém:**  
`shuffle()` před sortem znamená, že při **stejných** hodnotách (všechni 0, stejná zóna) je pořadí náhodné. Při opakovaných bězích nebo deterministickém seedu může stále vyhrávat stejná osoba. Navíc první úkol v dávce má u všech denní počet 0 → výběr je v podstatě náhodný z freeCandidates, ne „nejméně zatížený“.

**Návrh úpravy (koncepčně, bez změny engine – pokud by se měl engine upravit):**  
- Primární řazení podle **denního počtu úkolů** (asc), bez předchozího shuffle, nebo shuffle **až mezi kandidáty se stejným denním počtem**.  
- Tím se deterministicky upřednostní kandidát s **nejnižším počtem úkolů v daný den**.  
- Pokud úpravy engine nejsou povoleny: v **provideru** před voláním engine **seřadit** kandidáty podle předem spočítaného denního počtu (z `existingTasksRaw` + `toInsert`) a předat engine už seřazený seznam; engine pak bere „prvního volného“. To vyžaduje, aby engine garantoval, že bere prvního kandidáta, který projde overlap checkem (což dělá – vybere `freeCandidates.first` po sortu). Takže provider může předřadit „nejméně zatížené“ a engine je zkontroluje v pořadí – první bez kolize vyhrává. **Pozor:** engine si kandidáty sám filtruje na `freeCandidates` a pak sortí; takže pořadí vstupních `candidates` ovlivňuje jen to, kdo je první v `freeCandidates` před sortem. Až po sortu se bere první. Takže pokud chceme „nejméně zatížený“ bez změny engine, musíme v provideru předem vyfiltrovat a seřadit kandidáty a předat je v pořadí „od nejméně zatíženého“ – ale engine pak z nich stejně udělá overlap check a vlastní sort. Aby měl smysl „upřednostnit nejméně zatíženého“ v provideru, musel by engine buď brát kandidáty v pořadí (první volný bez kolize = vítěz), nebo provider musí nějak předpočítat „kdo je volný“ a seřadit – to je duplicitní logika. **Nejčistší** je upravit engine: řadit primárně podle denního počtu (a případně shuffle jen mezi rovnými). V analýze to navrhnu jako změnu v engine (s poznámkou, že je locked) a alternativu v provideru (předřazení kandidátů podle denního zatížení, pokud engine neměníme).

---

## 4. Fallback logika („násilné“ přiřazení)

### Kdy engine vrací `assignTo == null`

- Na začátku: `candidates.isEmpty` → návrat `(assignTo: null, ...)`.
- Po smyčce přes `shiftAttempt`: pokud pro **všechny** posuny (u posuvných úkolů až 100× po 30 min) **žádný** kandidát není bez překryvu (`freeCandidates` vždy prázdné), smyčka končí a na konci funkce je `return (assignTo: null, ...)`.
- U **svatých** úkolů se neposouvá čas (`shiftAttempt` jen 1) – pokud v daném čase nikdo není volný, vrátí null.

Engine tedy **nepřiřadí** nikoho, pokud není aspoň jeden kandidát bez kolize v daném (nebo posunutém) čase. Není tam „force assign“ do kolize.

### Proč tedy zákazník vidí „násilné“ přiřazení

- **Špatná role:** Pokud provider pošle **špatné kandidáty** (např. všichni včetně uklízečky pro úkol „Prádelna“), engine vybere jednoho z nich – pro uživatele to vypadá jako „přiřazení na sílu“, i když z pohledu engine jde o „prvního volného z předaného seznamu“.  
- **Chybný overlap:** Pokud by parsování dat z `existingTasksRaw`/`toInsert` nebo časové pásmo způsobilo, že překryv se nevyhodnotí správně, engine by považoval kandidáta za volného i při reálné kolizi.

**Závěr:**  
Engine sám o sobě nevynucuje přiřazení při vyčerpání „bezpečných“ možností – v takovém případě vrací null. Pozorované „násilné“ přiřazení je konzistentní s **chybným složením kandidátů** (bod 1) nebo teoreticky s chybou v detekci překryvu.

---

## Návrh architektonického plánu oprav

### 3.1 Filtrování rolí (Skill Mismatch)

- **Generování (rezervace + scheduled):**  
  - Doporučit / vynutit v konfiguraci služeb vyplnění `required_role` pro každou službu, která má být přiřazována jen určité roli (např. Prádelna → driver).  
  - V UI katalogu služeb upozornit, že prázdné / „any“ znamená „kdokoli z personálu“.

- **Přepočet personálu:**  
  - **Varianta A:** Načíst pro úkoly s `service_id` příslušný záznam z `tenant_services` a použít `required_role` pro sestavení kandidátů. Pokud `service_id` chybí nebo služba nemá `required_role`, použít fallback mapování z `task_type`.  
  - **Varianta B (minimální):** Rozšířit mapování `task_type` → role v `recalculateAssignees`: přidat explicitní mapu (např. „prádelna“, „laundry“, „extra“ s konfigurovatelnou rolí) nebo heuristiku (služby obsahující „řidič“/„driver“/„transfer“ → drivers).  
  - Cíl: aby úkol „Prádelna“ (a podobné) nikdy nedostal kandidáty = celý tým, ale jen příslušnou roli (např. řidiče).

### 3.2 In-memory blokace (Overbooking)

- Zajistit **jednu** sdílenou proměnnou `toInsert` v rámci každého batch generování a předávat ji do **všech** volání `pickAssigneeWithCollisionAvoidance` v rámci tohoto batch.  
- Po každém přiřazení **vždy** přidat do `toInsert` záznam s `assigned_to`, `scheduled_start`, `due_date` ve formátu, který engine parsuje (`_parseTaskDateTimeUtc`).  
- Zkontrolovat všechna volání engine (generování z rezervací, scheduled, případně další) a ověřit, že žádné nepassuje uvnitř smyčky nový prázdný list.  
- Volitelně: jednotný helper „batch generator“, který přijímá seznam úkolů k vytvoření a sám drží jeden `toInsert` a volá engine v pořadí – aby se zabránilo omylu v budoucnu.

### 3.3 Load balancing

- **V engine (vyžaduje změnu locked souboru):**  
  - Primární řazení `freeCandidates` podle **denního počtu úkolů** (asc).  
  - `shuffle()` volat **až** mezi kandidáty se stejným denním počtem (ne před sortem), nebo ho odstranit a spoléhat na stabilní sort.  
  - Cíl: deterministicky upřednostnit kandidáta s **nejnižším** počtem úkolů v daný den.

- **Bez změny engine:**  
  - V provideru před voláním spočítat pro každého kandidáta denní počet úkolů (z `existingTasksRaw` + `toInsert`), seřadit `candidates` od nejméně zatíženého a předat engine. Engine pak při stejném denním počtu a zóně může stále brát „prvního“ – ten první bude mít nižší zatížení než kdyby byl seznam náhodný. (Přesné chování závisí na tom, zda engine sortí podle denního počtu – ano, ale až po shuffle. Takže bez úpravy engine zůstává shuffle před sortem a plný efekt „vždy nejméně zatížený“ bez úpravy engine není.)

### 3.4 Fallback

- Engine už při vyčerpání možností vrací `assignTo: null`.  
- Stačí zajistit správné sestavení kandidátů (bod 3.1) a správné předávání `toInsert` (bod 3.2).  
- Volitelně: v UI při zobrazení vygenerovaných úkolů zvýraznit úkoly s `assigned_to == null` jako „Nepřiřazeno – vyžaduje ruční přiřazení“, aby dispečer věděl, že jde o záměr, ne o chybu.

---

## Shrnutí bodů pro rozhodnutí

| # | Problém | Příčina | Kde řešit |
|---|--------|--------|-----------|
| 1 | Skill Mismatch (Prádelna → uklízečka) | Přepočet: mapování jen z `task_type`; „Prádelna“ spadá do else → všichni. Generování: služba bez `required_role` → všichni. | Provider: přepočet – role z `service_id` + katalog a/nebo rozšířené mapování task_type; generování – doporučení vyplnit required_role. |
| 2 | Overbooking (3 úkoly na stejný čas) | Pravděpodobně jiná cesta volání s prázdným `toInsert` nebo více nezávislých batchů bez sdílení `toInsert`. | Provider: jediná sdílená `toInsert` v rámci batch, audit všech volání engine. |
| 3 | Load balancing (jeden přetížený) | Shuffle před sortem; při stejné zátěži náhodný výběr; první úkol v dávce = náhodný. | Engine: řadit primárně podle denního počtu, shuffle jen mezi rovnými. Případně provider: předřadit kandidáty podle zatížení. |
| 4 | „Násilné“ přiřazení | Engine vrací null správně; problém je špatný seznam kandidátů (role) nebo chybná detekce kolize. | Po opravě bodů 1 a 2 by mělo „násilné“ přiřazení vymizet; jinak ověřit parsování časů a overlap. |

Po schválení tohoto plánu lze navrhnout konkrétní změny v souborech (provider, případně engine) a implementovat je krok po kroku.
