# Audit: Časy u úkolů (Tasks) a proč Admin nemůže editovat trvání / konec

**Kontext:** Bug – při editaci úkolu jde měnit „začátek“ (jedno datum/čas), ale ne trvání ani konec jako samostatné veličiny (např. zkrátit 3,5 h u „Praní“).

**Zdroje:** `lib/features/admin/admin_tasks_screen.dart` (`_AddTaskDialog`, `_EditTaskDialog`), `lib/features/admin/providers/admin_tasks_provider.dart` (`TaskRow`, generátory úkolů), migrace `supabase/migrations/20260221230000_add_task_real_timestamps.sql`, `20260221220000_add_metadata_to_tasks.sql`.

---

## 1. Datový model (DB / `TaskRow`)

### Sloupce tabulky `tasks` relevantní pro čas

| Sloupec | Role |
|--------|------|
| **`scheduled_start`** | Naplánovaný začátek okna úkolu (timestamptz). Při generování z rezervace bývá **začátek intervalu**; při ručním uložení z Admin dialogu se nastavuje na **stejnou hodnotu jako `due_date`** (viz bod 2). |
| **`due_date`** | Koncový čas okna / termín (timestamptz). U smart-generovaných úkolů je typicky **`scheduled_start + trvání`** (konec okna). |
| **`started_at`** | Reálný čas zahájení práce (timestamptz) – migrace času práce; **není součástí `TaskRow` modelu** v aplikaci jako pole (čte se z DB tam, kde je potřeba – např. reporty). |
| **`completed_at`** | Reálný čas dokončení (timestamptz); v `TaskRow` jako **`completedAt`**. |
| **`metadata`** | JSONB – může obsahovat např. `estimated_minutes` / `estimate_minutes` (**není povinné** při INSERT ze smart generátoru). |

### Kde je „plánované trvání“ (např. 3,5 h)?

- **Primárně jako rozdíl časů:** u automaticky generovaných úkolů platí **`trvání ≈ due_date − scheduled_start`** (v minutách). Hodnoty `scheduled_start` a `due_date` se nastavují zvlášť (např. `result.start` / `result.end` z plánovače kolizí).
- **Textový odhad v `description`:** generátor plní popis lokalizovaným textem typu „Odhad: X min“ (`admin.task_estimate_minutes` + číslo minut) – jde o **čitelný text**, ne o DB sloupec pro délku.
- **`metadata.estimated_minutes`:** používá se v částech aplikace jako **volitelný** přepis (worker countdown, reporty jako fallback), ale **smart generátor úkolů do metadat při INSERT typicky neukládá `estimated_minutes`** – odvod se dělá z intervalu a/nebo z popisu.
- **Tabulka `task_categories`:** obsahuje **`planning_priority`** (pořadí plánování), **ne délku úkolu** (`TaskCategoryModel`).

---

## 2. UI formulář (editace Adminem)

| Otázka | Odpověď |
|--------|---------|
| **Kde je formulář?** | **`lib/features/admin/admin_tasks_screen.dart`**: dialog **`_EditTaskDialog`** (veřejný vstup `AdminTasksScreen.showEditTaskDialog`). Přidání: **`_AddTaskDialog`**. Samostatný `task_form_dialog.dart` v repozitáři **není** – logika je v tomto souboru. |
| **Která časová pole jsou v UI?** | Jeden **`TextFormField`** s labelem z **`admin.task_field_due_date`** (`_dueDateController`), výběr přes **`_showDateTimePicker`**. Inicializace: **`_formatDateTime(t.dueDate)`** – tedy vychází z **`dueDate`** modelu (mapuje se z `due_date` / fallback `scheduled_start` při parsování). |
| **Proč není trvání / konec?** | Při **`_onSave`** se do Supabase posílá **jedna** hodnota `dueIso` a zapisuje se do **`due_date` i `scheduled_start` zároveň** (`'due_date': dueIso`, `'scheduled_start': dueIso`). Tím se **interval zhroutí na jeden okamžik** – zmizí původní rozdíl mezi začátkem a koncem. Neexistuje druhý picker pro konec ani pole pro minuty. |
| **`started_at` / `completed_at`** | Edit dialog **neposílá** úpravy `started_at` ani `completed_at` v ukázaném `updateFields` – ty se řeší jinými toky (stav úkolu, worker, atd.). |

---

## 3. Zdroj hodnot typu „3,5 hodiny“ (přednastavení)

Obecně **ne z `task_categories`** (tam je priorita plánování, ne délka).

1. **`tenant_services` (katalog služeb):** pole typu **`duration_minutes`** – základ délky služby (fallback např. 60 min, pokud chybí).
2. **`apartments.standard_cleaning_duration`:** přičítá se jen u typu služby **`cleaning`** – funkce **`_taskDurationMinutes`** vrací `apartmentStandardCleaning + serviceDurationMinutes`; u ostatních typů jen `serviceDurationMinutes` (nebo 60).
3. **„Svaté“ typy** (`_isSacredTaskType`: check-in/out, transfery): délka **jen** z katalogu (`svc.durationMinutes`), **bez** součtu s úklidem bytu.
4. **Natvrdo v kódu:** pouze **fallbacky** (např. 60 min), ne konkrétní název „Praní“ – konkrétní **3,5 h** vychází z **nastavení záznamu služby v DB** (duration) a typu služby (zda se přičítá standard úklidu).

Titulek úkolu (např. „Praní: …“) je z **názvu služby v katalogu** + host; **délka** z bodů výše.

---

## 4. Doporučená cesta k opravě (návrh – bez implementace)

**Cíl:** Admin může ručně upravit **odhad trvání** a/nebo **konec okna** bez ztráty srozumitelnosti pro reporty a kalendář.

### A) Oddělit začátek a konec v UI

- Přidat do **`_EditTaskDialog`** (a konzistentně i **`_AddTaskDialog`**) buď:
  - **dva** DateTime pickery: **`scheduled_start`** a **`due_date`**, **nebo**
  - jeden začátek + **číselné pole „trvání (min)“** a z něj dopočítat `due_date = scheduled_start + duration`.
- Při uložení **neposílet** stejný `dueIso` na oba sloupce, pokud uživatel explicitně nastavil interval.

### B) Persistovat odhad do `metadata` (doporučené pro reporty / worker)

- Při změně trvání zapsat **`metadata['estimated_minutes']`** (nebo sjednotit klíč s `parseTaskEstimateMinutes` v `task_countdown_timer.dart`).
- Reporty (`reports_provider`) už umí fallback na **`metadata.estimated_minutes`** – po vyplnění bude konzistentní i bez `started_at`/`completed_at`.

### C) `started_at` / `completed_at`

- Úprava **konce plánovaného okna** (`due_date`) je **nezávislá** na reálném **`completed_at`** – ten by měl zůstat řízený workflow dokončení úkolu; ruční edit **`completed_at`** jen pro výjimečné opravy (a s ohledem na audit).

### D) Shrnutí příčiny současného chování

Admin **má** jen jedno datum/čas pole mapované na **`due_date`**, přičemž uložení **přepíše i `scheduled_start` stejnou hodnotou**, takže **původní délka intervalu se neuchová** a uživatel nemá kontrolu nad trváním jako u generátoru.

---

## Stručné shrnutí jednou větou

Časové okno úkolu je v DB **`scheduled_start` + `due_date`**; trvání u generátoru vychází z **`tenant_services.duration_minutes`** a u úklidu z **`apartments.standard_cleaning_duration`**, zatímco Admin formulář ukládá **jeden timestamp do obou sloupců** a **nemapuje `metadata.estimated_minutes`**, takže nelze snadno zkrátit plánované 3,5 h bez rozšíření UI a mapování.
