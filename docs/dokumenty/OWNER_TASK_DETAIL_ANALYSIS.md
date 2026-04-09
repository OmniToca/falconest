# Analýza: Detail úkolu pro majitele (včetně fotografií)

**Cíl:** Umožnit majitelům (Property Owners) prohlížet detail úkolu – zejména `description`, `status` a `media_urls` (fotky z realizace / nahlášení závady).

**Scope:** Pouze analýza. Implementace až po odsouhlasení.

---

## 1. Existující detail úkolu (UI)

### Co v aplikaci je

| Obrazovka / komponenta | Použití | Read-only? | Poznámka |
|------------------------|--------|------------|----------|
| **TaskDetailScreen** (`lib/features/tasks/task_detail_screen.dart`) | Legacy; route `taskDetail` | **Ne** | **DEPRECATED.** Načítá z Isar/Drift (`taskDetailProvider`), má tlačítka „Zahájit úklid“, „Ukončit úklid“, „Vyfotit“. Silně svázaná s worker flow a ukládáním stavu. |
| **WorkerTaskDetailScreen** + typové obrazovky (`cleaning_task_screen`, `issue_task_screen`, …) | Worker (personál) | **Ne** | Načítá `WorkerTaskDetail` (obsahuje `mediaUrls`). Každý typ má vlastní flow: zahájit práci, dokončit s fotkou, vybrat částku atd. Není určeno pro „jen prohlížet“. |
| **Admin – _EditTaskDialog** (`admin_tasks_screen.dart`) | Admin | **Ne** | Plný edit: přiřazení, stav, popis, **fotky** (`_TaskMediaSection`). Zobrazení fotek je součástí edit dialogu. |
| **_OwnerTaskDetailDialog** (`owner_planning_calendar_screen.dart`) | Majitel – kalendář | **Ano** | Současný stav: pouze **AlertDialog** s řádky Typ, Název, Byt, Personál (generický text), Datum, Stav. **Chybí:** `description`, `media_urls` (fotky). Přijímá `PlanningTask` (z kalendáře). |

### Závěr k bodu 1

- **Existující „task detail“ obrazovky** (TaskDetailScreen, WorkerTaskDetailScreen, Admin edit dialog) **nejsou read-only** a jsou provázané s úpravami (přiřazení, stav, fotky, dokončení). Parametrizace `isReadOnly = true` by znamenala rozvětvení podmínek v mnoha místech a riziko, že se v budoucnu něco „otevře“ i majiteli.
- **Pro majitele už existuje** read-only dialog **`_OwnerTaskDetailDialog`**, ale zobrazuje jen základní metadata; **description** a **media_urls** v něm nejsou a ani data pro ně v kalendářovém kontextu zatím nejsou kompletní (viz bod 2).

---

## 2. Dostupnost dat (Provider & RLS)

### ownerTasksProvider (seznam úkolů majitele)

- **Soubor:** `lib/features/owner/providers/owner_tasks_provider.dart`
- **Dotaz:** `.from('tasks').select('*', apartments(name), reservations(...))` s `.inFilter('apartment_id', ownedApartmentIds)`.
- **Model:** `TaskRow.fromSupabaseRow(...)` → **TaskRow** má `description` i `mediaUrls` (parsování v `TaskRow.fromJson` → `_parseMediaUrls(json['media_urls'])`).
- **RLS:** Stejný dotaz je omezen RLS (např. `tasks_property_owner_select_own_apartments`); majitel vidí jen úkoly u vlastněných bytů.
- **Závěr:** Na **obrazovce Seznam úkolů** majitele jsou **description** i **media_urls** k dispozici v `TaskRow`.

### ownerPlanningCalendarTasksProvider (kalendář)

- **Soubor:** `lib/features/owner/providers/owner_planning_calendar_provider.dart`
- **Dotaz:** Explicitní `select`:  
  `'id, title, description, task_type, scheduled_start, due_date, status, assigned_to, apartment_id, metadata, apartments(name)'`.  
  **V selectu chybí `media_urls`.**
- **Model:** Parsování do **PlanningTask**. PlanningTask má pole **`description`**, ale **nemá `mediaUrls`** (ani v definici třídy v `planning_calendar_provider.dart`).
- **Závěr:** V **kalendáři** máme pro každý úkol **description**, ale **ne media_urls**. Aby majitel viděl fotky po kliknutí na úkol v kalendáři, bude potřeba buď rozšířit select + model (`PlanningTask` + `media_urls`), nebo načíst detail úkolu až po kliknutí (např. jeden dotaz na úkol podle `id` včetně `media_urls`).

### Shrnutí dostupnosti dat

| Kontext | Provider | description | media_urls |
|--------|----------|-------------|------------|
| Seznam úkolů (Owner) | ownerTasksProvider | ✅ v TaskRow | ✅ v TaskRow |
| Kalendář (Owner) | ownerPlanningCalendarTasksProvider | ✅ v PlanningTask | ❌ nevybíráme, model nemá |

RLS pro SELECT na `tasks` pro majitele už existuje; jde jen o to, **co konkrétně v dotazu vybíráme** a **co předáme do UI** (TaskRow vs PlanningTask).

---

## 3. Návrh architektury

### Varianta A: Znovupoužít stávající TaskDetailScreen / WorkerTaskDetailScreen s `isReadOnly = true`

- **Pro:** Jedna obrazovka pro více rolí.
- **Proti:**
  - **TaskDetailScreen** je deprecated a čte z Isar/Drift (taskDetailProvider), ne z Supabase; pro majitele bychom museli buď přidat jiný zdroj dat, nebo ho nepoužívat.
  - **WorkerTaskDetailScreen** a typové obrazovky (cleaning, issue, …) jsou plné akcí (start, complete, photo upload, collection). Přidat `isReadOnly` by znamenalo podmínky v mnoha widgetech a route by musela být dostupná jen pro majitele s „read-only“ payloadem. Riziko: v budoucnu někdo přidá nové tlačítko a zapomene na read-only větev.
  - Admin edit dialog je modal pro úpravu; zobrazit ho „jen pro čtení“ by vyžadovalo skrýt polovinu obsahu a neměnit data – větší změny v sdíleném kódu.

**Hodnocení:** Pro „majitel jen kouká na popis a fotky“ je varianta A **méně vhodná** – složitější údržba a vyšší riziko úniku editací do majitelského pohledu.

### Varianta B: Vlastní read-only pohled jen pro majitele (rozšíření stávajícího dialogu / jednoduchá obrazovka)

- **Pro:**  
  - **Bezpečnost:** Jedna jasná hranice – majitelský detail **nikdy** nevolá update, přiřazení ani worker flow. Žádné sdílené tlačítko „Uložit“ nebo „Dokončit“.  
  - **UX:** Obsah přesně na míru: nadpis, stav, popis, galerie fotek. Žádné pole „Přiřadit“, „Změnit stav“, „Nahrát fotku“.  
  - **Kód:** Střed už máme – **`_OwnerTaskDetailDialog`** v `owner_planning_calendar_screen.dart`. Stačí ho rozšířit (nebo vytáhnout do sdíleného widgetu) o zobrazení `description` a sekci fotek z `media_urls`.  
  - **Data:**  
    - Z **kalendáře:** buď doplnit `ownerPlanningCalendarTasksProvider` o `media_urls` a rozšířit **PlanningTask** o `List<String> mediaUrls`, nebo po kliknutí na úkol načíst detail jedním dotazem (např. `ownerTaskDetailProvider(taskId)`) vracející read-only DTO s popisem a `media_urls`.  
    - Ze **seznamu úkolů:** už máme `TaskRow` s `description` i `mediaUrls` – stačí při kliknutí na řádek otevřít tentýž read-only dialog a předat mu tato data (případně společný model „OwnerTaskDetail“ s title, status, description, mediaUrls, …).

**Hodnocení:** Pro náš případ (majitel nic nemění, jen prohlíží popis a fotky) je **varianta B bezpečnější a vhodnější na UX i údržbu**.

### Doporučení

- **Zvolit variantu B:**  
  - Jednotný **read-only** detail pro majitele (dialog nebo lehká full-screen stránka), který zobrazuje pouze: typ úkolu, název, byt, datum/čas, **stav**, **popis**, **galerie fotek** (`media_urls`).  
  - Žádné editační ani worker akce.  
  - Používat ho jak z **kalendáře** (po kliknutí na úkol), tak ze **seznamu úkolů** (po kliknutí na řádek).  
- **Data:**  
  - V **seznamu** už máme vše v `TaskRow` (včetně `description`, `mediaUrls`).  
  - V **kalendáři** buď:  
    - rozšířit `ownerPlanningCalendarTasksProvider` o sloupec `media_urls` a model `PlanningTask` o `mediaUrls`, a předat je do stávajícího dialogu,  
    - nebo zavedení **ownerTaskDetailProvider(taskId)** načítajícího jeden úkol (s RLS) včetně `description` a `media_urls`, a dialog by po otevření z kalendáře načetl detail tímto providerem (bez rozšiřování PlanningTask).

Tím zůstane čistá hranice „majitel = jen čtení“ a jeden konzistentní způsob zobrazení detailu včetně fotek.
