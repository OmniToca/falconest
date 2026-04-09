# Analýza: Sloučení rezervací a úkolů v Plánovacím kalendáři (Owner Portal)

**Cíl:** V jednom kalendáři zobrazit jak **naplánované úkoly** (úklidy/údržba), tak **rezervace** (obsazenost bytu) pro majitele.

**Scope:** Pouze analýza a návrh architektury. Implementace až po odsouhlasení.

---

## 1. Současný stav kalendáře

### Balíček
- **Žádný externí kalendářový balíček** (ani Syncfusion, ani table_calendar).
- Kalendář je **vlastní implementace**: týdenní mřížka (0–24 h, sloty po 15 min), 7 sloupců = dny, řádky = časy. Vykreslování přes `SingleChildScrollView` + `Stack` + `Positioned` karty.

**Soubory:**
- `lib/features/owner/owner_planning_calendar_screen.dart` – UI
- `lib/features/owner/providers/owner_planning_calendar_provider.dart` – načítání úkolů pro majitele
- `lib/features/calendar/providers/planning_calendar_provider.dart` – sdílený model `PlanningTask`, `getProcessedTasksForWeek`, `parseDurationMinutesFromDescription`

### DataSource / události
- **Zdroj:** pouze úkoly z tabulky `tasks`. Mapování jde z **Supabase řádku** → **`PlanningTask`** (ne přímo z `TaskRow`; admin používá `TaskRow`, kalendář používá `PlanningTask`).
- **Začátek události:** `PlanningTask.scheduledStart` (DateTime – načtený z `scheduled_start`, převedený do lokálního času).
- **Konec události:** v modelu **není**. Odvozuje se v runtime:
  - `parseDurationMinutesFromDescription(task.description)` – parsuje z popisu řetězce typu „1 hod 30 min“, „1h“, „60 min“ atd. (multijazyčně).
  - Fallback: **60 minut**.
- Pozice a výška karty v mřížce: `startMinutes` z `scheduledStart`, `durationMinutes` z popisu; layout řeší překrývání přes `getProcessedTasksForWeek` (dayIndex, colIndex, totalCols).

---

## 2. Zdroje dat (providers)

### Je na obrazovce `ownerReservationsProvider`?
- **Ne.** `OwnerPlanningCalendarScreen` aktuálně sleduje jen:
  - `ownerPlanningCalendarTasksProvider(_weekStart)` – úkoly pro týden
  - `taskCategoriesProvider` – kategorie pro barvy/ikony úkolů
- `ownerReservationsProvider` existuje v `lib/features/owner/providers/owner_reservations_provider.dart` a načítá rezervace pro vlastněné byty (RLS), ale na této obrazovce se **nepoužívá**.

### Rezervace – pole pro začátek a konec bloku v kalendáři
Model **`OwnerReservation`** má:
- **`startDate`**, **`endDate`** – datum příjezdu / odjezdu (typ `DateTime`; v DB pravděpodobně datum bez času, parsované např. jako půlnoc).
- **`arrivalTime`**, **`departureTime`** – volitelné `DateTime?` (konkrétní čas příjezdu/odjezdu, pokud se eviduje).

Pro zobrazení v týdenní mřížce:
- **Začátek bloku:**  
  - buď `startDate` (např. 00:00)  
  - nebo pro první den pobytu `arrivalTime`, pokud je vyplněno.
- **Konec bloku:**  
  - buď konec posledního dne (`endDate` 23:59 nebo `endDate.add(1 den)` 00:00 podle konvence „end = exclusive“)  
  - nebo pro poslední den `departureTime`, pokud je vyplněno.

Rezervace typicky zasahují **více dní**. Každý den v intervalu `<startDate, endDate>` lze zobrazit jako jeden blok (např. „celodenní“ pruh v daném sloupci).

---

## 3. Návrh řešení (architektura)

### 3.1 Sloučení TaskRow a rezervací do jednotného zdroje

- **Nepoužívat** přímo `TaskRow` – kalendář už dnes pracuje s **`PlanningTask`**. Rezervace nejsou úkoly, takže je vhodné je nesnažit „nalít“ do `PlanningTask`, ale zavést společnou vrstvu pro kalendářové události.

**Doporučení:**

1. **Abstrakce „kalendářová událost“**  
   Zavedení typu (např. **sealed class** nebo **sum type**), který reprezentuje jeden záznam v kalendáři:
   - **Task:** `PlanningTask` + odvozené `start` = `scheduledStart`, `end` = start + `parseDurationMinutesFromDescription(description)`.
   - **Reservation:** `OwnerReservation` + pro každý den v intervalu `[startDate, endDate]` jeden záznam s `start`/`end` (buď 00:00–23:59, nebo `arrivalTime`/`departureTime` na první/poslední den).

2. **Provider**  
   Nový provider (např. **`ownerPlanningCalendarEventsProvider(weekStart)`**), který:
   - načte `ownerPlanningCalendarTasksProvider(weekStart)` a `ownerReservationsProvider`,
   - vyfiltruje rezervace, které se protínají s daným týdnem,
   - převede úkoly i rezervace na společný seznam „událostí“ s jednotným rozhraním: `id`, `start: DateTime`, `end: DateTime`, `type: 'task' | 'reservation'`, plus reference na původní `PlanningTask?` nebo `OwnerReservation?` (pro detail / barvu / popisek).

3. **Rozšíření layoutu**  
   - Stávající **`getProcessedTasksForWeek`** bere `List<PlanningTask>`. Buď:
     - **Varianta A:** Nová funkce **`getProcessedEventsForWeek(List<CalendarEvent> events, ...)`**, která umí jak úkoly (čas v rámci dne), tak rezervace (např. all-day). Vrací např. `List<WeekProcessedEvent>` s `event`, `dayIndex`, `colIndex`, `totalCols`, a příznakem `isAllDay`.
     - **Varianta B:** Rezervace převést na „syntetické“ úkoly (scheduledStart = 00:00, duration = celý den) – jednodušší, ale méně čisté a hůř rozlišitelné v typech.

Doporučení: **Varianta A** – jeden typ `CalendarEvent` (sealed: TaskEvent | ReservationEvent) a společná `getProcessedEventsForWeek`.

### 3.2 Vizuální odlišení „Rezervace“ vs „Úklid/Údržba“

- **Rezervace (obsazenost):**
  - **Barva:** vlastní paleta – např. zelená / tyrkysová / neutrální šedá, odlišná od barev typů úkolů (`TaskVisuals`).
  - **Umístění:** ideálně **all-day pruh** nad časovou mřížkou v každém dni (jeden řádek „celodenní události“ nad sloupcem 0–24 h), aby bylo zřejmé, že jde o obsazenost celého dne, ne o konkrétní hodinu.
  - **Popisek:** např. „Rezervace“ + název bytu (popř. host), bez personálu.

- **Úkoly (úklid/údržba):**
  - **Barva a styl:** ponechat současné chování podle `task_type` a `TaskVisuals` (barva, ikona).
  - **Umístění:** v časové mřížce na konkrétní čas podle `scheduledStart` a délky z popisu (jako dnes).

Technicky:
- Pokud přidáte **all-day sekci**, v layoutu bude nad mřížkou (pod hlavičkou dnů) jeden řádek s 7 buňkami; do nich se vykreslí pouze rezervace (jeden pruh za byt/rezervaci v daném dni, nebo sloučený blok „Obsazeno“).
- Úkoly zůstanou v `Stack`u na časové mřížce podle `getProcessedEventsForWeek` (případně jen pro `type == task`).

### 3.3 Interakce

- **Tap na úkol:** stávající read-only dialog (`_OwnerTaskDetailDialog`).
- **Tap na rezervaci:** nový read-only dialog (např. „Rezervace – byt X, host Y, interval …“) bez editace.

---

## Shrnutí

| Otázka | Odpověď |
|--------|--------|
| Balíček kalendáře | Vlastní týdenní mřížka (žádný Syncfusion/table_calendar). |
| DataSource | Pouze úkoly → `PlanningTask`; začátek = `scheduledStart`, konec = odvozen z `parseDurationMinutesFromDescription(description)` (default 60 min). |
| `ownerReservationsProvider` na obrazovce | Není; lze přidat a použít v novém sloučeném provideru. |
| Pole rezervace pro začátek/konec | `startDate`, `endDate`; volitelně `arrivalTime`, `departureTime`. |
| Sloučení dat | Nový typ `CalendarEvent` (task | reservation), provider `ownerPlanningCalendarEventsProvider`, funkce `getProcessedEventsForWeek`. |
| Vizuální odlišení | Rezervace: all-day pruh nad mřížkou, vlastní barva; úkoly: v mřížce podle času, stávající barvy dle typu. |

Po odsouhlasení tohoto návrhu lze přistoupit ke krokové implementaci (model → provider → rozšíření layoutu a UI).
