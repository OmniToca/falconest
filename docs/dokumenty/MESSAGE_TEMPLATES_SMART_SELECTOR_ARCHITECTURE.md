# Architektura: Smart Template Selector (Šablony zpráv na správných místech)

**Cíl:** Dostát šablony zpráv (WhatsApp s předvyplněným textem) na všechna relevantní místa v UI pro Adminy i Workery, s manuální kontrolou (uživatel zkontroluje text a sám odešle). Jedna znovupoužitelná komponenta + chytré filtrování podle kontextu.

---

## 1. Analýza současného stavu

### Kde se šablony aktuálně zobrazují a dají prokliknout

| Místo | Soubor | Popis |
|-------|--------|--------|
| **Worker – pouze Transfer** | `lib/features/worker/screens/task_types/transfer_task_screen.dart` | Sekce „Rychlé zprávy hostovi“ (`_buildQuickMessagesSection`). Zobrazí se **všechny šablony vrácené providerem** – žádné filtrování v UI. |

**Jinde šablony v UI nejsou** – ani v ostatních typech úkolů (Úklid, Check-in, Údržba…), ani v admin části (rezervace, úkoly).

### Jak je to technicky řešené

- **Provider (Worker):**  
  `messageTemplatesForWorkerProvider(tenantId)`  
  - **Mobil:** `message_templates_provider_mobile.dart` – načte šablony z Drift (SQLite), **filtruje jen na `trigger_context == null/empty nebo 'transfer'`**, seřadí podle `orderIndex`.  
  - **Web:** `message_templates_provider_web.dart` – načte z API (Supabase), bez tohoto filtru (nutno ověřit a sjednotit).

- **Merge a odeslání v Transfer obrazovce:**  
  - `TemplatePlaceholderService.resolveGuestPhone(detail)` – fallback řetěz: `detail.guestPhone` → `detail.clientPhone` → rezervace → parsování z poznámky.  
  - `TemplatePlaceholderService.buildContextFromTask(detail)` – sestaví mapu `guest_name`, `guest_phone`, `flight_number`, `address`, `keybox`, `reference_number`, `apartment_name`, `owner_notes`.  
  - `TemplatePlaceholderService.replacePlaceholders(template.body, contextMap)` – nahradí `{placeholder}` v textu.  
  - **url_launcher:** `launchUrl(Uri.parse('https://wa.me/$cleanedPhone?text=$encodedText'), mode: LaunchMode.externalApplication)` – otevře nativní WhatsApp s předvyplněným číslem a textem.

- **Kontext:** Pouze `WorkerTaskDetail` (z `workerTaskDetailProvider(taskId)`). Rezervace ani byt se do placeholderů explicitně neředí v transfer_task_screen; `buildContextFromTask` umí brát volitelně `ReservationPlaceholderContext` a `ApartmentPlaceholderContext`, ale v transferu se nevolají.

**Shrnutí:** Jediné místo použití = Worker Transfer. Provider na mobilu omezuje šablony na „obecné“ a „transfer“. Merge + wa.me je v transfer_task_screen lokálně v metodě `_sendTemplateMessage`.

---

## 2. Návrh univerzální komponenty: Smart Template Selector

### 2.1 Název a forma

- **Název:** `MessageTemplateSelectorBottomSheet` (nebo `MessageTemplateSelectorDialog` – dle preferencí UX; bottom sheet je na mobilu pohodlnější).
- **Umístění:** např. `lib/features/communication/widgets/message_template_selector_bottom_sheet.dart`.
- **Rozhraní:** Zavolá se odkudkoliv (Admin i Worker) s **jedním kontextovým objektem**, který určí:
  - pro jakého hosta/rezervaci/úkol se text generuje,
  - jaké šablony se mají **preferovat** (chytré filtrování).

### 2.2 Kontext předávaný do komponenty

Potřebujeme jednotný typ „kontextu“, ze kterého umíme vyrobit:
1) **mapu placeholderů** (pro merge),
2) **telefon hosta** (pro wa.me),
3) **seznam preferovaných `trigger_context`** (pro filtrování šablon).

**Návrh – společný typ kontextu:**

```dart
/// Kontext pro Smart Template Selector – určuje zdroj dat (host, byt, úkol) a preferované kategorie šablon.
sealed class MessageTemplateSelectorContext {
  /// Worker: detail úkolu (Úklid, Transfer, Check-in, …). Placeholdery z WorkerTaskDetail.
  /// Preferované trigger_context: [taskType] + null (obecné).
  factory MessageTemplateSelectorContext.fromWorkerTask(WorkerTaskDetail detail) = WorkerTaskTemplateContext;

  /// Admin: rezervace (Kanban karta, Edit rezervace). Placeholdery z rezervace + volitelně byt.
  /// Preferované trigger_context: check_in, check_out, transfer_in, transfer_out + null.
  factory MessageTemplateSelectorContext.fromReservation(ReservationRow reservation, {ApartmentPlaceholderContext? apartment}) = ReservationTemplateContext;

  /// Admin: úkol (Detail úkolu / Edit task dialog). Placeholdery z TaskRow + volitelně rezervace (pro guest_phone).
  /// Preferované trigger_context: [task.taskType] + null.
  factory MessageTemplateSelectorContext.fromAdminTask(TaskRow task, {ReservationRow? reservation}) = AdminTaskTemplateContext;
}
```

- **WorkerTaskTemplateContext:**  
  - Merge: stávající `TemplatePlaceholderService.buildContextFromTask(detail, reservation: …, apartment: …)`.  
  - Telefon: `TemplatePlaceholderService.resolveGuestPhone(detail, reservation: …)`.  
  - Preferované kontexty: `[detail.taskType, null]` (např. `cleaning` + obecné).

- **ReservationTemplateContext:**  
  - Merge: **nová metoda** `TemplatePlaceholderService.buildContextFromReservation(ReservationRow, {ApartmentPlaceholderContext?})` → stejné klíče (`guest_name`, `guest_phone`, `address`, …).  
  - Telefon: z rezervace (a případně z bytu/klienta, pokud rozšíříme).  
  - Preferované kontexty: `['check_in', 'check_out', 'transfer_in', 'transfer_out', null]` (nebo všechny kategorie vztahující se k pobytu – konfigurovatelné).

- **AdminTaskTemplateContext:**  
  - Merge: buď sestavit „minimální“ `WorkerTaskDetail` z `TaskRow` + `ReservationRow`, nebo přidat `buildContextFromAdminTask(TaskRow, ReservationRow?)` do služby.  
  - Telefon: z rezervace nebo z TaskRow (pokud máme reservationGuestPhone v budoucnu).  
  - Preferované kontexty: `[task.taskType, null]`.

Implementace může být třída s podtřídami nebo jeden record s `enum ContextSource { workerTask, reservation, adminTask }` a příslušnými daty – dle vkusu; důležité je mít jedno vstupní „kontextové“ API pro bottom sheet.

### 2.3 Chytré filtrování šablon

- **Vstup:** Seznam všech šablon (pro Worker z Drift, pro Admin z `messageTemplatesAdminProvider` – tedy Supabase).  
  - **Důsledek:** Na mobilu pro Worker je třeba buď **zrušit** filtr „jen transfer“ v `messageTemplatesForWorkerProvider`, a filtrovat až v selectoru, **nebo** mít druhý provider „všechny šablony pro selectora“ (např. bez filtru). Doporučení: **jednotný zdroj „všechny šablony“** a filtrování až v UI selectora.

- **Pravidlo v selectoru:**  
  - Zobrazit šablony, kde `trigger_context` je **null** (obecné) **nebo** je v seznamu **preferovaných kontextů** pro daný typ volání (viz výše).  
  - **Pořadí:** nejdřív šablony s přesně odpovídajícím `trigger_context` (např. pro Úklid nejdřív `cleaning`), pak obecné (`null`), případně ostatní kategorie až na konec (volitelné).

- **Příklad:**  
  - Volání z **detailu úkolu Úklid** → preferované `['cleaning', null]` → v seznamu uvidí „Je uklizeno“ (cleaning) a „Obecná zpráva“ (null).  
  - Volání z **rezervace** → preferované `['check_in','check_out','transfer_in','transfer_out', null]` → uvidí šablony pro příjezd/odjezd/transfer a obecné.

### 2.4 Jednotný flow v komponentě

1. Otevře se bottom sheet (nebo dialog) s předaným `MessageTemplateSelectorContext`.
2. Načtou se šablony (Worker: stávající provider bez transfer-only filtru / Admin: `messageTemplatesAdminProvider`). Pro Admin bude potřeba na webu vracet stejný tvar dat jako `MessageTemplateRow` (nebo adapter na společný model pro selector).
3. Z kontextu se vypočítá seznam preferovaných `trigger_context` a seznam šablon se **vyfiltruje a seřadí**.
4. Uživatel vidí seznam šablon (název + případně štítek kategorie). Klik na položku:
   - Z kontextu se sestaví mapa placeholderů (volání služby podle typu kontextu).
   - Provede se `replacePlaceholders(template.body, contextMap)`.
   - Z kontextu se získá telefon hosta; pokud chybí, zobrazí se SnackBar („Zadejte telefon hosta“) a wa.me se nevolá.
   - Jinak: vyčistí se číslo (`replaceAll(RegExp(r'[^\d]'), '')`), sestaví `https://wa.me/$cleanedPhone?text=$encodedText`, `launchUrl(..., LaunchMode.externalApplication)`.
5. Po otevření WhatsAppu se bottom sheet zavře (nebo zůstane otevřený pro další šablonu – dle UX).

Veškerá logika merge + wa.me by měla být **v jednom místě** (např. v `TemplatePlaceholderService` + malá helper funkce `openWhatsAppWithTemplate(...)` v communication modulu), aby nedocházelo k duplicitě s `transfer_task_screen.dart`.

---

## 3. Rozšíření TemplatePlaceholderService a zdroje šablon

- **buildContextFromReservation(ReservationRow, {ApartmentPlaceholderContext? apartment}):**  
  Vrátí `Map<String, String>` se stejnými klíči jako `buildContextFromTask`. Vyplní např. `guest_name`, `guest_phone` z rezervace, `apartment_name`, `address`, `keybox`, `owner_notes` z apartment; chybějící prázdný řetězec.

- **resolveGuestPhone z rezervace:**  
  Buď přímo `reservation.guestPhone`, nebo nová statická metoda `resolveGuestPhoneFromReservation(ReservationRow, {Client? pokud máme})`.

- **Admin kontext z TaskRow + ReservationRow:**  
  Buď `buildContextFromAdminTask(TaskRow task, ReservationRow? reservation, {ApartmentPlaceholderContext? apartment})`, nebo sestavení „syntetického“ `WorkerTaskDetail` z TaskRow + rezervace a použití stávajícího `buildContextFromTask`. Druhá varianta zmenší duplicitu.

- **Zdroj šablon pro Worker v selectoru:**  
  - Varianta A: Nový provider `messageTemplatesForSelectorProvider(tenantId)` – na mobilu načte z Drift **všechny** šablony (bez filtru trigger_context). Filtrování jen v selectoru.  
  - Varianta B: Stávající `messageTemplatesForWorkerProvider` upravit tak, aby **nepoužíval** filtr (vracel všechny); v `transfer_task_screen` by se pak zobrazovaly všechny šablony, dokud tam zůstane inline sekce. Po zavedení selectora lze transfer obrazovku přepnout na jediné tlačítko „Napsat hostovi“ → otevře selector (s kontextem `fromWorkerTask(detail)`), a filtr „transfer + obecné“ bude pouze uvnitř selectora.  
  Doporučení: **Varianta B** – jeden provider bez filtru; filtr pouze v selectoru. Na mobilu tedy v `message_templates_provider_mobile.dart` **odstranit** filtr na transfer a vracet všechny šablony.

---

## 4. Mapování UI – kam umístit tlačítko „WhatsApp“ / „Napsat hostovi“

### 4.1 ADMIN

| Místo | Soubor / widget | Jak integrovat |
|-------|------------------|----------------|
| **Kanban karta rezervace** | `admin_reservations_screen.dart` – widget karty rezervace (např. `_ReservationKanbanCard` nebo ekvivalent, kde se vykresluje jedna rezervace) | V akční řádek nebo ikony u karty přidat ikonu/tlačítko „WhatsApp“ nebo „Napsat hostovi“. Při tapu: `MessageTemplateSelectorBottomSheet.show(context, ref, MessageTemplateSelectorContext.fromReservation(reservation, apartment: …))`. Apartment načíst z provideru podle `reservation.apartmentId` (např. již načtený v seznamu bytů). |
| **Detail rezervace (Edit dialog)** | `admin_reservation_forms.dart` – `EditReservationDialog` | V AppBar nebo v patičce dialogu tlačítko „Napsat hostovi“. Kontext: `fromReservation(widget.reservation, apartment: …)`. |
| **Detail úkolu v adminu (Edit task dialog)** | `admin_tasks_screen.dart` – `_EditTaskDialog` | Tlačítko „Napsat hostovi“ v dialogu. Kontext: `fromAdminTask(task, reservation: reservation)` – rezervaci načíst podle `task.reservationId` (např. `reservationsForTaskProvider` nebo jednorázový fetch). |

### 4.2 WORKER

| Místo | Soubor | Jak integrovat |
|-------|--------|----------------|
| **Detail jakéhokoliv úkolu** | Všechny `*_task_screen.dart` (Transfer, Úklid, Check-in, Check-out, Údržba, atd.) | **Jednotný přístup:** Do sdíleného layoutu (např. `WorkerTaskSharedHeader` nebo nový společný widget „akce nad úkolem“) přidat tlačítko/ikonu „WhatsApp“ / „Napsat hostovi“. Při tapu: otevřít `MessageTemplateSelectorBottomSheet.show(context, ref, MessageTemplateSelectorContext.fromWorkerTask(detail))`. |
| **Konkrétně Transfer** | `transfer_task_screen.dart` | **Refaktor:** Stávající sekci „Rychlé zprávy hostovi“ (inline tlačítka šablon) **nahradit** jedním tlačítkem „Napsat hostovi“, které otevře nový bottom sheet. Tím odstraníme duplicitu logiky merge/wa.me a získáme konzistentní UX se zbytkem úkolů. |

**Sdílené místo pro Worker:**  
Nejčistší je mít jedno místo, kde se vykresluje tlačítko „Napsat hostovi“ pro všechny typy úkolů – např. v **AppBar** každé `*_task_screen.dart` (jako v Transferu ikona „Report problem“). Alternativa: společný widget, který každá obrazovka vloží do svého layoutu (např. nad kartou Kontakt). Doporučení: **ikona v AppBar** na všech task typech (Transfer, Cleaning, Check-in, Check-out, Maintenance, …), volající stejně `MessageTemplateSelectorBottomSheet.show(..., fromWorkerTask(detail))`.

---

## 5. Shrnutí kroků implementace

1. **Kontext a služba**  
   - Zavedení `MessageTemplateSelectorContext` (worker task / reservation / admin task) a helperů pro placeholder mapu a telefon z každého typu.  
   - Rozšíření `TemplatePlaceholderService`: `buildContextFromReservation`, popř. `buildContextFromAdminTask` nebo mapování TaskRow+Reservation → WorkerTaskDetail.

2. **Zdroj šablon**  
   - Mobil: v `message_templates_provider_mobile.dart` odstranit filtr na transfer; vracet všechny šablony.  
   - Web (Worker): sjednotit, že provider pro selector vrací všechny šablony.

3. **Komponenta MessageTemplateSelectorBottomSheet**  
   - Přijímá `MessageTemplateSelectorContext`, načte šablony, vyfiltruje a seřadí podle preferovaných `trigger_context`, zobrazí seznam.  
   - Při výběru: merge placeholderů z kontextu, validace telefonu, `openWhatsAppWithTemplate(...)` (jedna sdílená funkce s url_launcher).

4. **Umístění v UI**  
   - Admin: rezervační Kanban karta, Edit rezervace dialog, Edit task dialog.  
   - Worker: AppBar (nebo sdílený blok) u všech task obrazovek; v Transferu odstranit inline „Rychlé zprávy“ a nahradit je otevřením selectora.

5. **i18n a drobnůstky**  
   - Překlady pro „Napsat hostovi“, „Vyberte šablonu“, chyby (chybí telefon).  
   - Zachovat stávající klíče pro šablony a kategorie (`admin.task_type_*`, `communication.template_trigger_general`).

Tím docílíme jediného místa pro logiku „vyber šablonu → merge → wa.me“, chytrého filtrování podle kontextu a konzistentního umístění tlačítka na všech relevantních místech bez duplicity kódu.
