# Návrh: Audit Log pro otevření WhatsApp odkazu (Smart Template Selector)

**Cíl:** Logovat úmysl uživatele – kdo, kdy, komu (telefon) a jaký zmergovaný text byl připraven k odeslání. Skutečné odeslání v nativním WhatsAppu nelze detekovat.

---

## 1. Zápis do logu – kde a jak

### Kde volat `AuditLogService.log`

**Doporučení: zavolat zápis uvnitř `_onTemplateTap` hned po přípravě dat a před `launchUrl`.**

- **Před `launchUrl`:** Logujeme „uživatel zvolil šablonu a my jsme vygenerovali odkaz“ – to odpovídá požadavku Product Ownera. Záznam vznikne vždy, i když pak např. `canLaunchUrl` selže nebo uživatel WhatsApp zruší.
- **Po `launchUrl` v `then()`:** Záznam by vznikl jen při úspěšném otevření; při chybě bychom nic nelogovali.
- **Závěr:** Volat **před** otevřením odkazu. Po sestavení `parsedText`, `cleanedPhone` a `url` (a případně `source` z kontextu) zavolat zápis, poté beze změny pokračovat stávajícím `try { canLaunchUrl + launchUrl } catch … finally { pop }`.

### Bezpečnost a UX – selhání zápisu nesmí blokovat WhatsApp

- Zápis do audit logu **nesmí** v hlavním flow vyhodit výjimku ani čekat na výpadek sítě tak, že by se neotevřel WhatsApp.
- **Řešení:** Vlastní blok kolem volání audit logu:
  - `try { await AuditLogService.log(...) } catch (_) { /* tiché – např. debugPrint nebo Sentry */ }`
  - Žádné `rethrow`. Hlavní flow (otevření odkazu, `Navigator.pop`) probíhá vždy stejně.
- Volající kód tedy: připraví `details` → (v try-catch) zapíše log → pak beze změny spustí `canLaunchUrl` / `launchUrl` / `pop`. Pokud zápis selže, uživatel stejně uvidí WhatsApp (nebo chybovou hlášku z `launchUrl`) a bottom sheet se zavře.

---

## 2. Struktura dat pro zápis

### actionType

- **Hodnota:** `'WHATSAPP_LINK_OPENED'`
- **Konstanta:** Doporučuje se přidat do `audit_log_shared.dart` vedle `AuditActionType.softDelete` např. jako `AuditActionType.whatsappLinkOpened = 'WHATSAPP_LINK_OPENED'`, aby se nepoužíval „magic string“ v UI i v zápisu.

### Parametry volání `AuditLogService.log`

- **tenantId / userId:** Z `authNotifierProvider` (nebo ekvivalentu) – stejně jako jinde v aplikaci.
- **tableName:** `null` – akce nepatří k jedné konkrétní tabulce. (Případně volitelně `'communication'` pro budoucí filtry; pro zobrazení lze rozlišovat podle `actionType`.)
- **recordId:** `null` – nemáme jeden „záznam“, který by akce měnila.

### Mapa `details` (doporučené klíče)

| Klíč             | Typ     | Popis |
|------------------|--------|--------|
| `record_name`    | String | Pro titul v seznamu logů. Např. `"WhatsApp → +420 123 456 789"` (telefon s mezerami pro čitelnost). Naplnit z `phone` (před očištěním, aby byl formát s +). |
| `guest_phone`    | String | Telefon v plném tvaru (např. +420…). Admin vidí, komu byl odkaz připraven. |
| `template_name`  | String | Název šablony (např. „48h před transferem“). |
| `message_preview`| String | Zmergovaný text zprávy. Kvůli délce a čitelnosti **zkrátit** např. na 200–300 znaků + `"…"` pokud je delší. |
| `source`         | String | Zdroj kontextu: `'worker_task'` \| `'reservation'` \| `'admin_task'`. Určíme podle typu `MessageTemplateSelectorContext` (WorkerTaskTemplateContext / ReservationTemplateContext / AdminTaskTemplateContext). |
| `task_type`      | String?| (Volitelně) Pouze u `worker_task`: `detail.taskType` (cleaning, transfer_in, …). |
| `reservation_id` | String?| (Volitelně) U kontextu z rezervace nebo admin úkolu s rezervací – pro propojení na entitu. |
| `task_id`        | String?| (Volitelně) U worker_task / admin_task – ID úkolu. |

- `record_name` zajistí srozumitelný **název řádku** v seznamu (kdo komu).
- `guest_phone` + `template_name` + `message_preview` + `source` dávají Adminovi plný přehled bez nutnosti rozebírat JSON.

---

## 3. Zobrazení v UI (audit_log_display_helpers.dart)

### auditLogActionToTranslationKey

- Přidat `case` pro `'WHATSAPP_LINK_OPENED'` (nebo `AuditActionType.whatsappLinkOpened`).
- Nový i18n klíč např. `super_admin.audit_log_action_whatsapp_link_opened` → překlad např. „Otevření WhatsApp zprávy“.

### Titul řádku (title)

- Již teď se používá `EnterpriseAuditPayload.getRecordName(entry.details)` → `record_name`.
- Stačí do `details` ukládat `record_name` ve tvaru např. `"WhatsApp → +420 123 456 789"`. Pak bude na první pohled jasné, že jde o WhatsApp na konkrétní číslo.

### Podtitul / metadata řádku

- `recordSuffix` v audit_log_screen je `getAuditLogDisplayNameFromDetails(entry) ?? shortRecordId(entry.recordId)`.
- `getAuditLogDisplayNameFromDetails` už bere `record_name` z `details` – takže `recordSuffix` může být stejný text nebo ho můžeme nechat; hlavní je, že **title** je z `record_name` a je čitelný.

### Třetí řádek – details (formatAuditLogDetailsForDisplay)

- V `formatAuditLogDetailsForDisplay` přidat větévku pro akci `WHATSAPP_LINK_OPENED`:
  - Číst z `details`: `template_name`, `message_preview`, `source`.
  - Sestavit jeden řádek např.:
    - „Šablona: {template_name} · Náhled: {message_preview zkrácený} · Zdroj: {překlad source}“.
  - Překlady pro `source`: např. `super_admin.audit_log_whatsapp_source_worker_task`, `_reservation`, `_admin_task`.

### Ikona v seznamu

- Dnes: `getAuditLogIconForTable(entry.tableName)` → pro `tableName == null` vrací `Icons.description_outlined`.
- **Možnosti:**
  - **A)** Rozšířit `getAuditLogIconForTable` tak, že pro `tableName == null` a zápis s `actionType == WHATSAPP_LINK_OPENED` (když bychom to tam předali) vrací např. `Icons.chat`.
  - **B)** Přidat `getAuditLogIconForAction(String actionType)` a v audit_log_screen.dart použít: pokud je `actionType == WHATSAPP_LINK_OPENED`, zobrazit `Icons.chat`, jinak `getAuditLogIconForTable(entry.tableName)`.
- **Doporučení:** Varianta **B** – jedna funkce `getAuditLogIconForAction(actionType, tableName)`: pro `WHATSAPP_LINK_OPENED` vrátit `Icons.chat`, jinak fallback na stávající `getAuditLogIconForTable(tableName)`. V UI pak volat tuto jednu funkci.

---

## 4. Shrnutí

- **Kde logovat:** V `MessageTemplateSelectorBottomSheet._onTemplateTap`, po přípravě `parsedText` a `cleanedPhone`, **před** voláním `canLaunchUrl` / `launchUrl`. Zápis obalit do vlastního `try/catch` bez rethrow.
- **actionType:** `'WHATSAPP_LINK_OPENED'` (konstanta v AuditActionType).
- **details:** `record_name` (titul), `guest_phone`, `template_name`, `message_preview` (zkrácený), `source` (worker_task | reservation | admin_task), volitelně `task_type`, `reservation_id`, `task_id`.
- **UI:** Nový překlad pro akci, `record_name` = titul řádku, v `formatAuditLogDetailsForDisplay` větévka pro WHATSAPP_LINK_OPENED (šablona, náhled, zdroj), ikona přes novou/rozšířenou helper funkci (chat ikona pro tuto akci).

Tím bude v Audit Logu jasný záznam: kdo, kdy, komu (telefon) a jaký zmergovaný text byl připraven, bez toho aby selhání zápisu bránilo otevření WhatsAppu.
