# Audit report: Generátor úkolů („Zlaté vejce“)

**Datum auditu:** 21. 2. 2025  
**Soubory analyzované:** `admin_tasks_provider.dart`, `admin_tasks_screen.dart`, `reservation_services_repository.dart`, `task_assignment_engine.dart`

---

## 1. VSTUPNÍ DATA – co se načítá při kliku na „Generovat návrhy“

### Spouštění generátoru

1. Uživatel klikne na tlačítko „Generovat návrhy (max 50)“ v `_TopActionBar` (`admin_tasks_screen.dart`).
2. Zavolá se `_runGenerateSmartTasks()` → `notifier.generateSmartTasks()` + `notifier.generateScheduledTasks()`.
3. Oba metody jsou v `AdminTasksNotifier` (`admin_tasks_provider.dart`).

### Databázové dotazy v `generateSmartTasks()`

| Pořadí | Tabulka | Dotaz | Účel |
|--------|---------|-------|------|
| 1 | `tasks` | `.select('reservation_id, service_id')` + `.eq('tenant_id', ...)` | Kontrola duplicit – které (rezervace, služba) už mají úkol |
| 2 | `tasks` | `.select()` celá tabulka | Seznam úkolů pro collision avoidance přiřazení |
| 3 | `apartment_services` | `.select('apartment_id, service_id, trigger_type')` | Služby přiřazené k bytům – které úkoly generovat |
| 4 | `tenant_services` | přes `tenantServicesProvider` | Katalog služeb (název, serviceType, requiredRole, durationMinutes) |

### Provider data (bez přímého Supabase dotazu v generátoru)

- `adminReservationsProvider.future` – rezervace (dotaz v provideru: `reservations` select)
- `apartmentsProvider.future` – byty
- `adminTeamProvider.future` – tým (profily + zóny)
- `staffAbsencesProvider.future` – absence personálu

### Kritické zjištění: **reservation_services se NENAČÍTÁ**

- Dotaz na tabulku `reservation_services` se při generování úkolů **neprovádí**.
- `adminReservationsProvider` načítá pouze z `reservations` – bez JOINu na `reservation_services`.
- Generátor tedy **nepracuje** s daty:
  - `custom_note`
  - `charged_price`
  - `payer_type`
  - které uživatel vyplní v Tabu 2 formuláře rezervace.

---

## 2. TOK DAT PRO TRANSFERY / CHECK-IN / ÚKLID

### Místo vzniku nových úkolů

**Soubor:** `lib/features/admin/providers/admin_tasks_provider.dart`  
**Metoda:** `generateSmartTasks()`  
**Řádky:** cca 406–425 (blok `toInsert.add({...})`)

### Smyčka generování

```
for each reservation r:
  for each service svc in servicesByApartment[r.apartmentId]:  // apartment_services
    for each taskDate in datesToCreate:  // podle trigger_type
      → vytvoř úkol s title, description, task_type, ...
```

### Složení pole `description`

**Aktuální kód (ř. 411):**

```dart
final description = getEstimateMinutesText?.call(totalMinutes)
    ?? 'admin.task_estimate_minutes'.tr(namedArgs: {'minutes': totalMinutes.toString()});
```

**Obsah description:** pouze lokalizovaný odhad času, např. „Odhad: 60 min“.

**Do description se NEVKLÁDÁ:**
- `custom_note` z `reservation_services`
- žádná poznámka hosta
- žádná interní poznámka z rezervace

### Složení dalších polí úkolu

| Pole | Zdroj |
|------|-------|
| `title` | `'${svc.serviceName}: $guestName'` (např. „Transfer na letiště: Novák“) |
| `task_type` | `_resolveTaskType(requiredRole, serviceType, serviceName)` |
| `reservation_id` | `r.id` |
| `service_id` | `svc.serviceId` (tenant_services.id) |
| `apartment_id` | `r.apartmentId` |
| `assigned_to` | výsledek `pickAssigneeWithCollisionAvoidance` |
| `scheduled_start`, `due_date` | z časového výpočtu (štafetový kolík, transfery atd.) |

---

## 3. MAPOVÁNÍ SLUŽEB

### Jak generátor určuje typ úkolu

**Metoda:** `_resolveTaskType(requiredRole, serviceType, serviceName)`  
**Umístění:** `admin_tasks_provider.dart`, ř. 1162–1181

| Podmínka | Výsledný task_type |
|----------|--------------------|
| role/type/name obsahuje „transfer“, „řidič“, „driver“ | `Transfer` |
| „check-in“ / „check-out“ | `Check-in` / `Check-out` |
| Jinak | `serviceType` z katalogu (cleaning, maintenance, extra) |

### Vazba na reservation_services

**Žádná –** generátor neprochází `reservation_services`.

- Používá jen `apartment_services` (služby nastavené pro byt).
- Pro každou rezervaci generuje úkoly pro **všechny** služby z `apartment_services` s trigger typy `before_checkin`, `after_checkout`, `both_ways`, `on_demand`.
- Nerozlišuje, které služby uživatel v rezervačním formuláři vybral (Tab 2).
- Nerozlišuje, ke které službě patří poznámka v `reservation_services.custom_note`.

### Schéma vazeb

```
tenant_services (katalog)
    ↑
apartment_services (služby bytu: apartment_id, service_id, trigger_type)
    ↑
reservation_services (výběr pro konkrétní pobyt: apartment_service_id, custom_note)
```

- Generátor pracuje s `apartment_services` → `tenant_services`.
- `reservation_services` odkazuje na `apartment_services.id` (`apartment_service_id`).
- V `_ServiceTrigger` je zatím jen `serviceId` (tenant_services.id), **chybí** `apartmentServiceId` (apartment_services.id), který by byl potřeba pro mapování na `reservation_services`.

---

## 4. BEZPEČNÝ BOD ZÁSAHU PRO custom_note

### Doporučené místo

**Metoda:** `generateSmartTasks()`  
**Bod:** těsně před `toInsert.add({...})`, cca ř. 412.

### Důvod

1. Všechny výpočty (čas, přiřazení, collision avoidance) jsou již hotové.
2. `task_assignment_engine.dart` zůstává beze změny.
3. Jediná úprava je sestavení `description`.
4. Logika času a přiřazení personálu zůstává nedotčena.

### Navrhovaný postup (pro budoucí implementaci)

1. **Načíst reservation_services** hromadně na začátku `generateSmartTasks()`:
   ```dart
   // Pseudo: pro všechny reservation IDs z reservations
   // SELECT * FROM reservation_services WHERE reservation_id IN (...)
   ```

2. **Sestavit mapu** `(reservation_id, apartment_service_id) → custom_note`.

3. **Do `_ServiceTrigger` doplnit `apartmentServiceId`**, aby bylo možné párování:
   - v selectu `apartment_services` přidat sloupec `id`;
   - při vytváření `_ServiceTrigger` předávat `apartmentServiceId: map['id']`.

4. **Před `toInsert.add`** upravit `description`:
   ```dart
   var description = getEstimateMinutesText?.call(totalMinutes) ?? ...;
   final customNote = reservationServicesByResAndApt[r.id]?[svc.apartmentServiceId]?.customNote;
   if (customNote != null && customNote.trim().isNotEmpty) {
     description = '$description\n\n$customNote';  // nebo jiný formát
   }
   ```

### Rizika a omezení

- **Výkon:** jeden hromadný dotaz na `reservation_services` je obvykle přijatelný.
- **Řazení:** poznámka by měla být přidána za odhad času, aby bylo jasné, co je systémový údaj a co poznámka uživatele.
- **Neřešené:** filtr „generovat jen pro služby vybrané v rezervaci“ – to by znamenalo další logickou vrstvu a pravděpodobně změnu v rozhodování, které úkoly se vůbec zakládají.

---

## 5. SOUHRN

| Otázka | Odpověď |
|--------|---------|
| Načítá generátor `reservation_services`? | **Ne.** |
| Kde se tvoří nové úkoly? | `admin_tasks_provider.dart`, `generateSmartTasks()`, blok `toInsert.add`. |
| Z čeho se skládá `description`? | Pouze z lokalizovaného odhadu času v minutách. |
| Mapuje se `reservation_services` na typy úkolů? | **Ne.** Generátor používá jen `apartment_services` + `tenant_services`. |
| Kde bezpečně přidat `custom_note`? | Těsně před `toInsert.add`, po všech výpočtech času a přiřazení personálu. |

---

## 6. DIAGRAM TOKU (zjednodušený)

```
[Klik "Generovat návrhy"]
        │
        ▼
generateSmartTasks()
        │
        ├─► Načti: reservations, apartments, team, apartment_services, tenant_services
        │   (reservation_services NENAČÍTÁ)
        │
        ├─► Pro každou rezervaci r:
        │     Pro každou službu svc z apartment_services bytu r:
        │       Výpočet taskStart, taskEnd, assignTo (task_assignment_engine)
        │       description = "Odhad: X min"  ← ZDE CHYBÍ custom_note
        │       toInsert.add({ title, description, ... })
        │
        └─► Supabase insert(toInsert)
```

---

*Report vygenerován automatickou analýzou kódu. Žádný kód nebyl změněn.*
