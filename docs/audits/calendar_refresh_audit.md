# Audit: Proč Plánovací kalendář nereaguje na změnu trvání úkolu

**Rozsah:** read-only analýza kódu (žádná oprava).  
**Související obrazovka:** `lib/features/calendar/screens/planning_calendar_screen.dart` (Admin záložka Plánovací kalendář – v `admin_layout.dart` jako `PlanningCalendarScreen`).  
**Data / model:** `lib/features/calendar/providers/planning_calendar_provider.dart`.

---

## 1. Mapping kalendáře (od TaskRow / API k „kostičce“)

| Fakt | Detail |
|------|--------|
| **Balíček** | **Nepoužívá se** `calendar_view`, `syncfusion_flutter_calendar` ani podobná knihovna. Jde o **vlastní mřížku** (`Column`/`Stack`/`Positioned`, 15min sloty) v `planning_calendar_screen.dart` (viz konstanty `_slotMinutes`, `_slotHeight`, `WeekGrid` / processed úkoly). |
| **Transformace** | Supabase odpověď se parsuje v `planning_calendar_provider.dart` ve **`_parseTasksFromResponse`** do modelu **`PlanningTask`** (lehký model pro kalendář – **není** to přímo `TaskRow`). |
| **Začátek bloku (`startTime`)** | Pro vykreslení se bere **`PlanningTask.scheduledStart`**. Při parsování řádku z DB se start počítá jako **`scheduled_start ?? due_date`** (první dostupné). |
| **Konec / výška bloku** | Model **`PlanningTask` nemá pole `dueDate` ani `endTime`**. Délka v minutách pro layout **není** z `due_date − scheduled_start`. Ve **`planning_calendar_screen.dart`** (řádky cca 707–713) se výška počítá jako: **`parseDurationMinutesFromDescription(p.task.description)`** – tedy z **textu `description`**, ne z DB intervalu ani z `metadata`. |
| **Fallback délky** | Funkce **`parseDurationMinutesFromDescription`** (`planning_calendar_provider.dart`): parsuje hodiny/minuty z řetězce (regexy pro `hod`/`h`/`min`/`mins`/…). Pokud **nenajde žádné minuty > 0**, vrací **pevných 60** minut – **ne** `due_date`. |
| **metadata** | `PlanningTask` obsahuje **`metadata`** z DB, ale **výška karty v týdenní mřížce ho pro trvání nepoužívá** (na rozdíl od např. worker `parseTaskEstimateMinutes`, které čte `estimated_minutes`). |

**Závěr k bodu 1:** Kalendář **vizuálně mapuje trvání výhradně přes `description`**, nikoli přes `due_date` ani `metadata.estimated_minutes`, přestože SELECT úkolů **`due_date` stahuje** (je v `.select(...)`, ale pro délku bloku se **nepoužije**).

---

## 2. State management (refresh dat)

| Fakt | Detail |
|------|--------|
| **Typ** | **`FutureProvider.family`**, ne `StreamProvider`. Konkrétně např. **`planningCalendarAllTasksProvider`** a **`planningCalendarDataProvider`** (`planning_calendar_provider.dart`). |
| **Chování** | Data se znovu načtou po **invalidaci** příslušného provideru nebo změně sledovaných závislostí (`ref.watch`). **Žádné** real-time `stream` z Postgresu pro tento pohled. |

---

## 3. Co se stane po uložení v `_EditTaskDialog`**

| Fakt | Detail |
|------|--------|
| **Uvnitř dialogu** | Po úspěšném `updateTaskInAdmin` se zavře dialog (`Navigator.pop`) a zavolá se **`widget.onSaved()`**. **Neprovádí se** zde žádná globální invalidace – záleží na předaném callbacku. |
| **Výchozí `showEditTaskDialog`** (`admin_tasks_screen.dart`) | Pokud volající **nepředá** vlastní `onSaved`, použije se default: **`ref.invalidate(adminTasksProvider)`** a **`ref.invalidate(adminTasksStreamProvider)`** – **bez** invalidace plánovacího kalendáře. |
| **Otevření z Plánovacího kalendáře** | V `planning_calendar_screen.dart` → `_openEditTask` se předává **vlastní** `onSaved`, který invaliduje mimo jiné **`planningCalendarAllTasksProvider`** a **`planningCalendarDataProvider`** (kromě `adminTasksProvider` / `adminTasksStreamProvider`). |

**Závěr k bodu 3:** Po uložení **není** univerzální „signál“ pro kalendář; záleží na místě otevření dialogu. Z kalendáře **invalidace tam je**, z jiných míst **typicky ne**.

---

## 4. Root cause (proč se blok nenatáhne)

1. **Primární příčina (mapování, ne refresh):** I po správném zápisu **`scheduled_start`** a **`due_date`** do `tasks` kalendář **délku bloku neodvozuje z tohoto intervalu**. Po refetchi má sice aktuální **`scheduled_start`** (posun začátku se může projevit), ale **výška** závisí na **`parseDurationMinutesFromDescription(description)`**. Uprava **trvání v novém formuláři** mění **`due_date` a `metadata.estimated_minutes`**, ale **`description` se automaticky nepřepisuje** na nový odhad – text často zůstane starý (např. původní „Odhad: … min“). Výsledek: **data v DB sedí, vizuál délky ne**, dokud se nezmění text v `description` nebo dokud kalendář nezačne brát délku z intervalu / metadat.

2. **Sekundární scénář (refresh):** Pokud uživatel otevře editaci **mimo** plánovací kalendář (např. ze seznamu úkolů), **default `onSaved` kalendář neinvaliduje** – kalendář se může **vůbec znovu nenačíst**, takže uživatel neuvidí ani posun začátku, dokud nepřepne záložku / neobnoví data ručně.

**Shrnutí:** Hlavní důvod „kostička se nenatáhne“ je **špatný zdroj trvání ve vykreslování** (popis vs. `due_date` / metadata), nikoli nutně absence refetch (ze záložky kalendáře se refetch děje). Kombinace obou výše platí podle vstupního místa editace.
