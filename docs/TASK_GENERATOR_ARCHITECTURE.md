# Modul „Zlaté vejce“ – Generátor úkolů (Smart Planner)

**Oficiální technická dokumentace** | FalcoNest B2B SaaS  
*Poslední aktualizace: únor 2026*

---

## Obsah

1. [Vstupní data a časové zóny](#1-vstupní-data-a-časové-zóny)
2. [Kotevní časy (Anchor Logic) a absence řetězení](#2-kotevní-časy-anchor-logic-a-absence-řetězení)
3. [Dispečerský Engine a řešení kolizí](#3-dispečerský-engine-a-řešení-kolizí)
4. [Ochrana databáze a UI vrstva](#4-ochrana-databáze-a-ui-vrstva)
5. [Životní cyklus a datové toky](#5-životní-cyklus-a-datové-toky)

---

## 1. Vstupní data a časové zóny

### 1.1 Parsování arrival_time a departure_time

Sloupce `arrival_time` a `departure_time` z tabulky `reservations` jsou typu `timestamptz`. Postgrest je vrací jako ISO8601 string (např. `"2026-02-22T08:00:00.000Z"`). V `ReservationRow.fromJson` se parsují přes `_parseOptionalDateTime(raw['arrival_time'])` – výsledek je `DateTime`.

### 1.2 Local Time Fix (proč NEPOUŽÍVAT toLocal())

**Problém:** Při použití `at.toLocal()` na UTC hodnotě docházelo k nechtěnému posunu +1 hodinu (např. 08:00 uložené jako 08:00Z se zobrazilo jako 09:00 v CET). Čas v rezervaci reprezentuje „hodiny na ciferníku“ – tj. co uživatel vybral (08:00 = osm hodin ráno), ne absolutní UTC okamžik.

**Řešení v kódu** (admin_tasks_provider.dart, řádky cca 1346–1364):

```dart
DateTime? _getReservationCheckInDateTime(dynamic r) {
  final at = r.arrivalTime;
  if (at != null) {
    return DateTime(at.year, at.month, at.day, at.hour, at.minute);
  }
  return _parseReservationCheckInDate(r.checkIn);
}

DateTime? _getReservationCheckOutDateTime(dynamic r) {
  final dt = r.departureTime;
  if (dt != null) {
    return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
  }
  return _parseReservationCheckOutDate(r.checkOut);
}
```

**Zásada:** Extrahují se `year, month, day, hour, minute` z parsovaného `DateTime` a z nich se sestaví nový lokální `DateTime` se stejnými čísly. Tím se ignoruje časová zóna uložené hodnoty a výsledek odpovídá přesně tomu, co uživatel vybral v UI. Žádné `toLocal()` ani další konverze.

### 1.3 Fallback při chybějících časech

Když `arrival_time` nebo `departure_time` je null, použije se:
- **Check-in:** `_parseReservationCheckInDate(r.checkIn)` – výchozí čas **15:00**
- **Check-out:** `_parseReservationCheckOutDate(r.checkOut)` – výchozí čas **10:00**

---

## 2. Kotevní časy (Anchor Logic) a absence řetězení

### 2.1 Důkaz absence řetězení (vymazání „vláčku“)

**generateSmartTasks (Fáze C):** V smyčce `for (final c in candidates)` neexistuje žádná sdílená proměnná typu `lastEndTime`, `currentStartTime` ani ekvivalent. Každá iterace vypočítává `taskStart` a `taskEnd` čistě z:

- `effectiveAnchor` – odvozený z `c.checkInDt` nebo `c.checkOutDt` (pro danou rezervaci neměnný)
- `effectiveDuration` – délka služby z katalogu

**generateScheduledTasks:** Původní logika „štafetového kolíku“ (`apartmentDayAvailableFrom`) byla odstraněna. Komentář v kódu (ř. cca 791): „Žádné řetězení: každý úkol se počítá z čistého taskDate. Striktní ukotvení bez vláčku.“ Každý scheduled úkol má `taskStart = taskDate`, `taskEnd = taskStart + duration`.

### 2.2 Určení efektivního anchoru

```dart
final effectiveAnchor = svc.triggerType == 'on_demand'
    ? taskDate
    : ((effectiveTaskType == 'transfer_in' || effectiveTaskType == 'check_in') ? c.checkInDt : c.checkOutDt) ?? taskDate;
```

| trigger_type | effectiveTaskType | effectiveAnchor |
|--------------|-------------------|-----------------|
| before_checkin | check_in, transfer_in | checkInDt |
| after_checkout | check_out, transfer_out, cleaning | checkOutDt |
| both_ways | transfer_in (na checkInDt) | checkInDt |
| both_ways | transfer_out (na checkOutDt) | checkOutDt |
| on_demand | extra apod. | taskDate (den po check-inu 10:00) |

### 2.3 Výpočet taskStart a taskEnd podle typu služby

**Svaté a odjezdové úkoly (check_in, check_out, transfer_out, cleaning):**

| Typ | Vzorec | Význam |
|-----|--------|--------|
| **check_in** | taskStart = anchor, taskEnd = anchor + duration | Začíná přesně v čas příjezdu hosta |
| **check_out** | taskStart = anchor, taskEnd = anchor + duration | Začíná přesně v čas odjezdu hosta |
| **transfer_out** | taskStart = anchor, taskEnd = anchor + duration | Auto čeká na hosta v čas odjezdu |
| **cleaning** | taskStart = anchor, taskEnd = anchor + duration | Startuje v čas odjezdu; engine ho při kolizi posune |

**Přímá implementace v kódu (ř. cca 661–669):**

```dart
if (effectiveTaskType == 'transfer_in') {
  taskEnd = effectiveAnchor;
  taskStart = effectiveAnchor.subtract(Duration(minutes: effectiveDuration));
} else {
  taskStart = effectiveAnchor;
  taskEnd = effectiveAnchor.add(Duration(minutes: effectiveDuration));
}
```

### 2.4 Zpětné plánování pro transfer_in

**Logika:** Transfer z letiště musí **skončit** přesně v okamžik příjezdu hosta (check-in). Řidič tedy musí vyjet dříve.

- `taskEnd = effectiveAnchor` (čas příjezdu hosta)
- `taskStart = effectiveAnchor - duration`

**Skutečná délka z databáze:** Pro Svaté úkoly (včetně transfer_in) se používá `effectiveDuration = svc.durationMinutes ?? 60` – přímo z katalogu služeb (`tenant_services.duration_minutes`), bez přičítání úklidu ani jiných korekcí. Pokud má transfer v DB 120 minut, odečítá se 120 minut.

Komentář v kódu: „Skutečná délka z katalogu služeb. Anchor time se resetuje pro každý úkol.“

---

## 3. Dispečerský Engine a řešení kolizí

Metoda `pickAssigneeWithCollisionAvoidance` (task_assignment_engine.dart) přiřazuje personál a při kolizi upravuje čas u flexibilních úkolů.

### 3.1 Svaté úkoly (nesmějí se posouvat)

**Definice:** `_isSacredTaskType(effectiveTaskType)` vrací true pro `check_in`, `check_out`, `transfer_in`, `transfer_out` a `transfer`.

**Chování:** Parametr `isSacredTask = true` → smyčka `shiftAttempt` proběhne **pouze jednou** (0..0):

```dart
for (int shiftAttempt = 0; shiftAttempt < (isSacredTask ? 1 : maxShiftIterations); shiftAttempt++) {
  DateTime tryStart = taskStart.add(Duration(minutes: shiftAttempt * shiftMinutes));
  ...
}
```

Výsledek: `tryStart = taskStart`, `tryEnd = taskEnd`. Čas se **nikdy nemění**. Při kolizi všech kandidátů engine vrátí `(assignTo: null, start: taskStart, end: taskEnd)` – úkol zůstane nepřiřazený, čas zůstane na anchor.

### 3.2 Flexibilní úkoly (úklid, údržba)

**Chování:** `isSacredTask = false` → až **100 iterací** s **30minutovými posuny**:

```dart
const int shiftMinutes = 30;
const int maxShiftIterations = 100;
for (int shiftAttempt = 0; shiftAttempt < maxShiftIterations; shiftAttempt++) {
  DateTime tryStart = taskStart.add(Duration(minutes: shiftAttempt * shiftMinutes));
  DateTime tryEnd = tryStart.add(taskDuration);
  // ... kontrola deadline, noční klid, kolize ...
}
```

- Iterace 0: původní čas (např. 08:00)
- Iterace 1: +30 min (08:30)
- Iterace 2: +60 min (09:00)
- … až po 99: +49,5 h

Engine hledá první časový slot, kde má alespoň jeden kandidát volno (žádný překryv s úkoly v DB ani v `toInsert`).

### 3.3 Deadline

`_computeTaskDeadlineForReservation(currentRes, allReservations)`:
1. Najde další rezervaci téhož bytu s check-in po check-out aktuální → `deadline = check-in` té další rezervace.
2. Pokud žádná další rezervace není → `deadline = checkOutDt + 3 dny`.

Pokud `tryEnd.isAfter(deadline)`, smyčka končí (break).

### 3.4 Noční klid (pracovní doba 07:00–19:00)

Platí pouze pro flexibilní úkoly s `applyNightRest = true` (úklid, údržba). Transfery a check-in/out nemají noční klid.

```dart
if (applyNightRest) {
  if (tryStart.hour < 7) {
    tryStart = DateTime(tryStart.year, tryStart.month, tryStart.day, 7, 0, 0);
    tryEnd = tryStart.add(taskDuration);
  }
  final workDayEnd = DateTime(tryStart.year, tryStart.month, tryStart.day, 19, 0, 0);
  if (tryStart.isAfter(workDayEnd)) {
    final nextDay = tryStart.add(const Duration(days: 1));
    tryStart = DateTime(nextDay.year, nextDay.month, nextDay.day, 7, 0, 0);
    tryEnd = tryStart.add(taskDuration);
  }
}
```

- **Před 07:00** → posun na 07:00 stejný den
- **Po 19:00** → posun na **07:00 následujícího dne**

---

## 4. Ochrana databáze a UI vrstva

### 4.1 Fallback prázdného JSON pro sloupec metadata

Sloupec `tasks.metadata` má v databázi **NOT NULL** constraint. Vygenerované úkoly bez finančních metadat by odeslaly `null`, což by způsobilo PostgrestException 23502.

**Řešení v modelu (TaskRow.toMap):**

```dart
map['metadata'] = metadata ?? {};
```

**Řešení v generátoru (generateSmartTasks, generateScheduledTasks):**

Metadata se sestavují jako `final metadata = <String, dynamic>{}` a při prázdném stavu se vždy posílá `'metadata': metadata` (prázdná mapa), nikdy null. Komentář v kódu: „Vždy posíláme metadata (min. prázdný objekt), protože DB sloupec metadata má NOT NULL constraint.“

### 4.2 UI: scheduledStart vs dueDate v detailu rezervace

V sekci „Související úkoly“ (admin_reservation_forms.dart, RelatedTasksList) se zobrazuje čas úkolu. Plánovací kalendář používá pro vykreslení bloku **začátek** úkolu (`scheduled_start`). Sloupec `due_date` reprezentuje **konec** úkolu.

**Implementace:** TaskRow má pole `scheduledStart` (parsované z `scheduled_start`). Subtitle v listu používá:

```dart
(t.scheduledStart ?? t.dueDate).toLocal()
```

Komentář: „Výpis používá skutečný naplánovaný začátek úkolu, aby se shodoval s kalendářem.“

Tím se eliminuje nesoulad, kdy by UI zobrazovalo čas konce (due_date) zatímco kalendář zobrazuje čas začátku (scheduled_start).

---

## 5. Životní cyklus a datové toky

### 5.1 Fáze generateSmartTasks

| Fáze | Akce |
|------|------|
| 0 | Inicializace: tenantId, rezervace, apartmány, tým, existující úkoly |
| 1 | Načtení apartment_services, tenant_services, reservation_services |
| A | Sbírka kandidátů: pro každou rezervaci a službu určení datesToCreate, vytvoření _SmartTaskCandidate |
| B | Řazení: planning_priority ↑, isBackToBack ↑, taskDate ↑ |
| C | Pro každého kandidáta: výpočet effectiveAnchor, taskStart, taskEnd, volání pickAssigneeWithCollisionAvoidance, sestavení záznamu do toInsert (max 50) |
| – | Hromadný INSERT do tasks |

### 5.2 Schéma datového toku

```
[reservations] (arrival_time, departure_time - Local Time Fix)
        +
[apartment_services] (trigger_type) + [tenant_services] (duration_minutes)
        +
[reservation_services] (volitelné služby, metadata)
        ↓
   Fáze A: _SmartTaskCandidate (checkInDt, checkOutDt, taskDate)
        ↓
   Fáze B: Řazení (planning_priority, back-to-back, taskDate)
        ↓
   Fáze C: Pro každého kandidáta
        effectiveAnchor (checkInDt / checkOutDt) — ŽÁDNÉ ŘETĚZENÍ
        effectiveDuration (z DB pro Svaté, taskBlockDuration pro cleaning)
        taskStart, taskEnd (anchor ± duration)
        pickAssigneeWithCollisionAvoidance (Svaté = 1 iterace, Flexibilní = až 100×30 min)
        ↓
   INSERT tasks (metadata: {} fallback, scheduled_start, due_date)
        ↓
   UI: RelatedTasksList používá scheduledStart (začátek) pro shodu s kalendářem
```

---

*Tento dokument slouží jako oficiální architektonická dokumentace modulu generátoru úkolů FalcoNest.*
