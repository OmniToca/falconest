# Audit: Výkonnost personálu (Reporty)

**Zdroj kódu:** `lib/features/admin/providers/reports_provider.dart`, UI `lib/features/admin/screens/reports_screen.dart` (`_StaffPerformanceSection`).  
**Účel:** Stručná fakta o agregaci bez návrhů změn.

---

## 1. Kde je logika?

| Co | Kde |
|----|-----|
| **Provider** | `reportsDataProvider` (`FutureProvider<ReportsSummary>`) v **`lib/features/admin/providers/reports_provider.dart`**. |
| **Agregace výkonu** | Ve stejném souboru uvnitř `reportsDataProvider`, po načtení `tasksInMonth`: smyčka `for (final t in tasksInMonth)` plní mapu `byEmployee` (`assigneeId` → `count` + součet `hours`). |
| **Model** | Třída **`EmployeePerformance`** (stejný soubor): `assigneeId`, `taskCount`, `hoursWorked`. |
| **UI** | **`_StaffPerformanceSection`** v **`reports_screen.dart`** – čte `summary.employeePerformances` a zobrazuje jméno z `teamFullListProvider` podle `profile.id` = `assigneeId`. |

---

## 2. Časový filtr a stav úkolů

| Aspekt | Chování |
|--------|---------|
| **Období** | **Kalendářní měsíc v UTC** podle **`reportsMonthProvider`** (`StateProvider<DateTime>`). Výchozí = `DateTime.now()`; UI mění měsíc přes **`_MonthPicker`** (šipky mění stav provideru). |
| **Hranice měsíce** | `startOfMonth = DateTime.utc(year, month, 1)`, `startOfNextMonth = DateTime.utc(year, month+1, 1)`. Dotaz: `completed_at >= startIso` **a** `completed_at < endIso` (konec výhradně jako začátek dalšího měsíce). |
| **Stav úkolů** | V dotazu je **`status == 'completed'`** a **`deleted_at IS NULL`**. Jiné stavy (plánované, rozpracované) se **neberou**. |
| **Limit** | `.limit(2000)` na výsledný výběr úkolů. |

---

## 3. Přiřazení (assignees)

| Aspekt | Chování |
|--------|---------|
| **Pole v DB** | Agregace používá výhradně **`tasks.assigned_to`** (v kódu: `assigneeId = (t['assigned_to'] as String?)?.trim() ?? ''`). |
| **Tabulka `task_assignees`** | V této agregaci **není použita** – neexistuje join ani čtení `assigned_user_ids`. |
| **Prázdný assignee** | `assigneeId == ''` → jeden bucket **„Nepřiřazeno“** (v UI přes i18n `admin.reports_unassigned`). |
| **Jméno v UI** | Mapování `assigneeId` → jméno přes **`teamFullListProvider`**: `m.profileId ?? m.id` musí odpovídat `assigned_to`. |

---

## 4. Výpočet hodin (`hoursWorked`)

Pořadí ve smyčce pro každý úkol (stejný soubor, komentáře v kódu odpovídají implementaci):

1. **Primárně reálný čas:** Pokud existují **oba** **`started_at`** a **`completed_at`** (parsované přes `_parseDateTime`), hodiny =  
   `(completed - started).inMinutes / 60.0` (desetinné hodiny).

2. **Fallback:** Pokud **chybí** některý z časů, čte se **`metadata`** (JSON):  
   **`estimated_minutes`** nebo **`estimate_minutes`** → hodnota se bere jako **minuty**, převod na hodiny = **`/ 60.0`**.

3. **Žádný zdroj:** Pokud neplatí bod 1 a v metadatech není použitelná hodnota, **`hours = 0`** pro daný úkol (přičte se k součtu, ale nepřidá odhad z jiných tabulek).

**Nepoužívá se** v této agregaci:

- `apartments.standard_cleaning_duration`
- přímé pole „estimated time“ mimo `metadata` u řádku úkolu (jen metadata výše)

**Součet:** Pro každého `assigneeId` se sčítají hodiny ze všech úkolů v měsíci podle pravidel výše → **`EmployeePerformance.hoursWorked`**.

---

## Shrnutí jednou větou

Výkonnost personálu v Reportech je **měsíční součet dokončených úkolů** (podle **`completed_at`** a **`reportsMonthProvider`**), seskupených podle **`tasks.assigned_to`**, s hodinami z **(completed_at − started_at)** nebo z **`metadata.estimated_minutes` / `estimate_minutes`**, jinak **0**.
