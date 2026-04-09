# Návrh: Přeřazení úkolu (Reassign Task)

## KROK 1: Analýza UI (shrnutí)

### Kde se úkol upravuje
- **Soubor:** `lib/features/admin/admin_tasks_screen.dart`
- **Dialog:** `_EditTaskDialog` (řádky cca 3064–3885)
- **Otevření:** 
  - Z Úkoly: `_showEditDialog(context, ref, task)` → `onEdit(task)` na kartě úkolu
  - Z jiných míst: `AdminTasksScreen.showEditTaskDialog(context, ref, task, onSaved: …, onReservationTap: …)`
- **Uložení:** `ref.read(adminTasksProvider.notifier).updateTaskInAdmin(widget.task.id, updateFields)` v `_onSave()`

### Aktuální chování vazeb
- **Úkol vázaný na apartmán** (`_isExternal == false`): zobrazuje se pouze dropdown **Apartmán**. Do `updateFields` jde `apartment_id`; `client_id` se **neposílá**, takže v DB zůstává stará hodnota.
- **Externí úkol** (`_isExternal == true`): zobrazuje se dropdown **Klient** (pouze agency/external z `clientsFullListProvider`). Do `updateFields` jde `client_id` a `apartment_id: null`.
- **Problém sirotků:** Pokud je `task.clientId` UUID smazaného klienta, ten v seznamu klientů není. Kód dnes nastaví `validValue = null` a v `addPostFrameCallback` přepíše `_selectedClientId = validValue`, takže se „ztratí“ a dropdown ukáže prázdnou hodnotu. Uživatel může vybrat nového klienta, ale zobrazení „aktuálního“ je matoucí a při nevyplnění validace hlásí „Vyberte klienta“.

### Proklik z Financí
- **Soubor:** `lib/features/admin/screens/finance_billing_screen.dart`
- **Komponenta:** `_BillingTaskTile` zobrazuje položku úkolu (název, datum, plátce, cena). `BillingTaskItem` má `taskId`.
- **Stav:** Na řádek úkolu **není** `onTap` – z podkladů pro fakturaci nelze otevřít úpravu úkolu.

### Repozitář
- **Soubor:** `lib/features/admin/providers/admin_tasks_provider.dart`
- **Metoda:** `updateTaskInAdmin(String taskId, Map<String, dynamic> updateFields)` – volá Supabase `tasks.update(updateFields)`. Přijímá libovolné sloupce včetně `client_id` a `apartment_id`.
- **Offline optimistic update:** V `copyWith` se aktualizuje `apartmentId`, ale **ne** `clientId` – po změně klienta by se v seznamu úkolů neprojevila.

---

## KROK 2: Návrh implementace

### 1. Do kterého souboru přidat co

| Co | Kde |
|----|-----|
| Úprava vazby (klient / apartmán) a sirotci | `lib/features/admin/admin_tasks_screen.dart` – `_EditTaskDialog` |
| Odeslání `client_id: null` u úkolu vázaného na byt + optimistic `clientId` | `lib/features/admin/providers/admin_tasks_provider.dart` |
| Proklik z řádku úkolu na editaci | `lib/features/admin/screens/finance_billing_screen.dart` – `_BillingTaskTile` + načtení úkolu |
| Načtení jednoho úkolu podle ID (pro Finance a případně jinde) | `lib/features/admin/providers/admin_tasks_provider.dart` – nový provider `taskByIdProvider` |
| Nové texty (i18n) | `assets/translations/cs.json`, `en.json`, `es.json` |

### 2. Chování z pohledu uživatele

- **Úpravy úkolu (stávající dialog):**
  - **Externí úkol a smazaný klient:** V dropdownu klienta se u sirotka zobrazí položka typu „Neplatný klient (ID: fc4ef7…)“ (zkrácené UUID), aby UI nespadlo a bylo jasné, že je potřeba vybrat nového. Uživatel vybere platného klienta a uloží → úkol se v Reportech/Financích přiřadí pod nového klienta.
  - **Úkol vázaný na apartmán:** Při uložení se kromě `apartment_id` explicitně pošle i `client_id: null`, aby po přechodu z externího na byt v DB nevznikal „zbytek“ starého klienta.
  - **Dokončený úkol (read-only):** Sekce **Přeřazení úkolu** zůstane editovatelná (jen vazba na klienta / apartmán), aby šlo opravit špatného klienta nebo byt i u hotového úkolu. Ostatní pole zůstanou zamčená (jako dnes).

- **Finance – Podklady pro fakturaci:**
  - Klik na řádek úkolu v seznamu položek k fakturaci otevře dialog úpravy úkolu (stejný `_EditTaskDialog`). Po uložení se obnoví data podkladů (invalidace providerů), takže se změna hned projeví v podkladech i v Reportech.

### 3. Konkrétní změny (bez Dart kódu – pouze návrh)

**A) `admin_tasks_screen.dart` – `_EditTaskDialog`**
- **Dropdown klienta (externí úkol):**
  - Pokud `_selectedClientId` není v seznamu klientů (agency/external), **nepřepisovat** ho na `null`.
  - Do položek dropdownu přidat jednu „sirotčí“ položku: hodnota = stávající `_selectedClientId`, label = klíč typu `tasks.client_orphan_label` s parametrem zkráceného ID (např. prvních 8 znaků UUID). Tím zajistíme, že UI nespadne a uživatel vidí, že jde o neplatného klienta.
  - Ostatní položky: prázdná volba „Vyberte klienta“ + všichni agency/external klienti. Po výběru nového klienta `setState(_selectedClientId = newId)`.
- **Sekce „Přeřazení úkolu“ (doplnění PROČ v komentáři):**
  - Nad stávajícími bloky Apartmán / Klient přidat nadpis (i18n), např. „Přeřazení úkolu – oprava vazby na klienta nebo byt (řešení sirotčích úkolů po smazání klienta).“
  - U **dokončeného** úkolu (`isReadOnly == true`) ponechat dropdowny **Apartmán** a **Klient** editovatelné (např. `onChanged` a `readOnly` řídit přes novou proměnnou `isReassignEnabled = !isFinanciallyLocked` pro tyto dva widgety). Při ukládání v režimu „jen přeřazení“ poslat v `updateFields` alespoň `apartment_id` a `client_id` (podle aktuálního režimu externí/byty).
- **Uložení:**
  - Když úkol **není** externí: do `updateFields` vždy přidat `'client_id': null`.
  - Když úkol **je** externí: `apartment_id: null` (už platí), `client_id: _selectedClientId` (už platí).

**B) `admin_tasks_provider.dart`**
- **`updateTaskInAdmin` – offline optimistic update:** V bloku, kde se sestavuje `updated = old.copyWith(...)`, doplnit `clientId: payload['client_id'] as String? ?? old.clientId` (a případně stejně pro `apartmentId`, pokud by se někde jinde přepisoval jen klient), aby se po změně klienta nebo bytu hned projevila v seznamu úkolů.
- **Nový provider `taskByIdProvider`:**  
  `FutureProvider.family<TaskRow?, String>((ref, taskId) async { ... })`  
  Načte jeden úkol z `tasks` podle `taskId` (tenant z `authNotifierProvider`), včetně joinů potřebných pro `TaskRow.fromSupabaseRow` (apartment name, assigned name). Použije se při otevření editace z Financí. Po úspěšném `updateTaskInAdmin` invalidovat i `taskByIdProvider(taskId)`.

**C) `finance_billing_screen.dart`**
- **`_BillingTaskTile`:** Přidat `onTap`. V callbacku načíst úkol přes `ref.read(taskByIdProvider(taskId).future)` (nebo ekvivalent), po obdržení `TaskRow` zavolat `AdminTasksScreen.showEditTaskDialog(context, ref, task, onSaved: () { ref.invalidate(billingReportProvider(param)); ref.invalidate(reportsDataProvider); })`. Přidat vizuální náznak, že je řádek klikatelný (např. `ListTile` s `onTap` a ikona šipky nebo „Upravit“).

**D) i18n**
- Nové klíče (příklady):
  - `tasks.client_orphan_label`: „Neplatný klient (ID: {id})“ – pro sirotčí položku v dropdownu.
  - `admin.tasks_reassign_section`: „Přeřazení úkolu“ – nadpis sekce.
  - `admin.tasks_reassign_section_hint`: „Lze změnit vazbu na klienta nebo byt (např. po smazání klienta v CRM).“ – krátký popis.
  - `admin.finance.billing_task_edit_tooltip`: „Upravit / přeřadit úkol“ – tooltip nebo doplněk u řádku úkolu ve Financích.

### 4. Repozitář – logika vazeb

- Při přepnutí úkolu na **vázaný na byt** (uživatel vybere apartmán): v `updateFields` posílat `apartment_id: <id>`, `client_id: null`.
- Při přepnutí na **externí** (uživatel vybere klienta, případně „jen externí“): `client_id: <id>`, `apartment_id: null` (to už formulář dělá).
- V `updateTaskInAdmin` se nic nemění na volání Supabase – pouze rozšíření `updateFields` z UI a doplnění optimistic update o `clientId` (a konzistence `apartmentId`), jak výše.

---

## Shrnutí

- **Soubor pro hlavní změny UI:** `admin_tasks_screen.dart` (`_EditTaskDialog` – dropdown klienta se sirotkem, sekce Přeřazení, editovatelné vazby i u dokončeného úkolu).
- **Repozitář:** `admin_tasks_provider.dart` (optimistic update + `taskByIdProvider`).
- **Proklik z Financí:** `finance_billing_screen.dart` (`_BillingTaskTile` + otevření edit dialogu po načtení úkolu).
- **i18n:** cs/en/es – nové klíče pro sirotka, sekci přeřazení a proklik z billing.
- **Uživatel:** Vidí v Reportech/Financích správného klienta; u smazaného klienta může v editaci vybrat nového (včetně zobrazení „Neplatný klient“); u dokončeného úkolu může měnit jen vazbu; z podkladů pro fakturaci se dostane jedním klikem na úkol do dialogu úpravy a po uložení se data obnoví.
