# UI konzistence – audit modulu `lib/features/admin/`

**Datum auditu:** 2026-03-18  
**Rozsah:** obrazovky (`*screen*.dart`), widgety, dialogy v `lib/features/admin/` (bez `providers/`).  
**Metoda:** statická analýza kódu (grep / čtení reprezentativních souborů).

---

## Shrnutí

| Oblast | Závažnost | Poznámka |
|--------|-----------|----------|
| Hardcoded `Colors.*` | Vysoká | Stovky výskytů napříč modulem; `Theme.of(context).colorScheme` je použit řádově méně často. |
| `TextStyle(fontSize: …)` mimo `textTheme` | Vysoká | Velké soubory (`admin_tasks_screen`, `admin_apartments_screen`, `admin_reservation_forms`, `reports_screen`, `admin_layout`, …). |
| `SafeArea` | Střední | Prakticky jen v `admin_layout.dart` a `wallet_detail_modal.dart`; většina obrazovek spoléhá na nadřazený layout. |
| `SingleChildScrollView` | Nízká–střední | Dialogy a dlouhé formuláře často ano; kořenové „hlavní“ obrazovky často `Column` + `Expanded` + scroll uvnitř seznamu. |
| `TextOverflow` / `maxLines` | Střední | Částečně u řádků v tabulkách/kartách; systematicky neověřeno u všech titulků. |
| Empty states | Smíšené | Někde ikona + i18n + CTA; jinde jen `Center` + `Text`. |
| Dialogy – pořadí akcí | Nízká | Typicky `TextButton` (zrušit) vlevo, `FilledButton` vpravo; výjimky `ElevatedButton`, místy jen jedno tlačítko. |
| Spacing | Střední | Opakující se `8`, `12`, `16`, `24`, ale **bez centrálních konstant** (`AppSpacing` v modulu chybí). |

---

## 1. Hardcoded barvy a styly

### 1.1 `Colors.*` místo `Theme.of(context).colorScheme`

**Četnost (orientační):** soubory s desítkami až stovkou výskytů `Colors.red/green/grey/...` zahrnují mimo jiné:

| Soubor | Typické použití |
|--------|-----------------|
| `admin_tasks_screen.dart` | SnackBary (`Colors.red`, `Colors.green`), rámečky Kanbanu, šedé odstíny pro metadata. |
| `admin_apartments_screen.dart` | Status badge barvy (`Colors.green/red/blue/...`), chybové stavy, SnackBary. |
| `admin_reservation_forms.dart` | `SnackBar` `backgroundColor`, `InputDecoration` border grey, šířky info boxů. |
| `admin_dashboard_screen.dart` | Sekční barvy, ikony, pozadí karet. |
| `admin_reservations_screen.dart` | Timeline barvy (`_timelineBlockColor`), chyby, texty. |
| `screens/finance_billing_screen.dart` | KPI, varování, nedoplatky, lock banner (amber). |
| `widgets/client_detail_dialog.dart` | Velmi husté použití `Colors.*` pro sekce, ikony, chyby. |
| `screens/reports_screen.dart` | KPI pozadí (`green.shade50`, `blue.shade50`), grafy, texty. |
| `admin_layout.dart` | Sidebar, badge, locked stavy. |
| `finance_dashboard_screen.dart` | Tab labely, indikátory modulů. |

**Důsledek:** tmavý režim / vlastní `ThemeData` nejsou konzistentně respektovány; kontrast a „error/success“ nejsou vázané na `colorScheme.error`, `onSurface`, `surfaceContainer`.

### 1.2 `TextStyle(fontSize: …)` mimo `textTheme`

Opakovaně se vyskytuje explicitní `fontSize` (10–18) a `TextStyle(color: Colors.grey.shade700)` místo:

- `Theme.of(context).textTheme.titleMedium` / `bodySmall` / `labelLarge`  
- `copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)`

**Příklady souborů s vysokou koncentrací:**

- `reports_screen.dart` – KPI čísla (např. `fontSize: 28`, `13`, `12`, `10`).
- `admin_team_screen.dart` – karty personálu, badge, dialogy.
- `admin_tasks_screen.dart` – karty úkolů, náhledy zpráv, dialogy.
- `admin_apartments_screen.dart` – tabulky, štítky, dialogy.
- `admin_layout.dart` – navigace, labely.
- `admin_reservation_forms.dart` – tabulky služeb, šablony.
- `components/wallet_indicator.dart` – `fontSize: 15` v `TextStyle`.

**Pozitivní vzor:** `admin_automation_rule_form.dart` místy používá `colorScheme.error` a `onSurfaceVariant` u validačních textů.

---

## 2. Responsivita a přetečení (overflow)

### 2.1 `SafeArea`

**Nalezeno výskytů `SafeArea`:** prakticky jen v:

- `admin_layout.dart` (obal obsahu)
- `widgets/wallet_detail_modal.dart`

Většina `Scaffold` těl v modulu (`admin_apartments_screen`, `admin_reservations_screen`, `admin_tasks_screen`, `finance_dashboard_screen`, …) **nepoužívá** vlastní `SafeArea` – pokud obrazovka není vždy vložena do layoutu s `SafeArea`, na zařízeních s výřezem / gesty může obsah zajíždět pod systémové prvky.

### 2.2 `SingleChildScrollView` a klávesnice

- **Dialogy** s formulářem (`client_form_dialog`, `wallet_topup_dialog`, `ad_hoc_message_dialog`, `settlement_split_dialog`, části `admin_reservation_forms`) často obsahují `SingleChildScrollView` – **dobré** pro přetečení při klávesnici.
- **Hlavní obrazovky** často: `Column` + `Expanded` + `ListView`/`ListView.builder` – vertikální scroll je uvnitř seznamu; **riziko** u obrazovek s pevným `Column` bez `Expanded` scrollu (závisí na konkrétní větvi buildu).

### 2.3 `TextOverflow` / dlouhé řetězce

- V částech kódu jsou použity `TextOverflow.ellipsis`, `maxLines` (grep např. v `admin_tasks_screen`, `admin_apartments_screen`, `admin_reservations_screen`, `client_detail_dialog`).
- **Systematické pokrytí není zřejmé**; dlouhé názvy hostů, adres, titulků úkolů v některých `Text(` mohou na úzkých šířkách stále přetékat, pokud nemají `Flexible`/`Expanded` + `overflow`.

**Doporučení:** projít kritické řádky (DataTable buňky, `ListTile` title/subtitle, Kanban karty) a sjednotit `maxLines` + `ellipsis` + `Tooltip` s plným textem.

---

## 3. Prázdné stavy (Empty States)

### 3.1 Silnější vzor (ikona + i18n + často akce)

| Místo | Popis |
|-------|--------|
| `admin_automations_screen.dart` | Záložka pravidel – ikona, text, tlačítka (seed / přidat). |
| `screens/finance_billing_screen.dart` | Prázdné podklady – ikona `receipt_long_outlined`, `admin.finance.billing_empty`. |
| `admin_apartments_screen.dart` | `admin.apartments_empty` / `admin.apartments_search_no_results` (text; bez velké ilustrace). |

### 3.2 Slabší / jen text

| Místo | Popis |
|-------|--------|
| `admin_reservations_screen.dart` | Kanban tab: `Center` + `Text` (`admin.reservations_empty` / search) – **bez ikony** oproti billing empty state. |
| `admin_tasks_screen.dart` | Prázdný seznam – použit klíč `admin.tasks_empty` v kontextu vyhledávání (ověřit konzistenci s ostatními). |

### 3.3 Obrazovky bez dedikovaného „empty“ UI (nebo jen „nulová data“ v grafech)

| Místo | Poznámka |
|-------|----------|
| `screens/reports_screen.dart` | Při nulových tržbách/úkolech se stále vykreslují sekce/grafy – **není** centrální empty state „žádná data za měsíc“. |
| `admin_dashboard_screen.dart` | Logika „fallback“ na nadcházející úkoly; úplně prázdný stav je třeba ověřit v UI (sekce mohou být prázdné bez jednotného empty widgetu). |
| `finance_dashboard_screen.dart` | Záložky – závisí na obsahu tabu; centrální empty komponenta není sjednocená s ostatními moduly. |
| `admin_zones_screen.dart` | Tělo deleguje na `ZonesListTab` (mimo tento grep) – empty stav je v settings widgetu. |

---

## 4. Dialogy a tlačítka; rozestupy

### 4.1 Pořadí akcí a typ tlačítka

- **Dominantní vzor:** `actions: [ TextButton(cancel), FilledButton(primary) ]` – soulad s Material zvyklostí (zrušit vlevo, potvrdit vpravo).
- **Nekonzistence typu:**
  - `admin_reservation_utils.dart` – `ElevatedButton` místo `FilledButton`.
  - `admin_tasks_screen.dart` – v jednom dialogu `ElevatedButton` pro výběr (`_confirmSelected`).
- **Jednoakční dialogy:** např. `finance_billing_screen.dart` – jen `TextButton` zavřít (OK).

### 4.2 Padding / margin

- Opakují se magická čísla: **`8`, `12`, `16`, `20`, `24`**, občas **`10`, `14`, `17`** (viz `admin_team_screen`, `reports_screen`).
- **Centrální** `AppSpacing` / sdílené konstanty v `lib/features/admin/` **nejsou** použity; srovnání s `core/presentation` (pokud existuje) není v tomto modulu vynucené.

---

## 5. Doporučené další kroky (mimo rozsah auditu)

1. Zavést **ten admin theme layer**: mapování `ColorScheme` + `TextTheme` extension pro „success/warning/info“ místo `Colors.green.shade700` atd.  
2. Přidat **sdílený `EmptyState`** widget (ikona volitelná, title, subtitle, volitelné CTA) a nasadit na rezervace, úkoly, reporty při nulových datech.  
3. Zvážit **`SafeArea`** wrapper pro obsah `Scaffold.body` u obrazovek používaných i na mobilu / webu v menším okně.  
4. Projektově sjednotit **SnackBar** barvy přes `colorScheme.error` / `inverseSurface` místo `Colors.red.shade700`.  
5. Audit **přístupnosti**: kontrast hardcoded šedí na `grey.shade600` pozadích vůči bílé.

---

*Dokument generován jako statický audit zdrojového kódu; chování za běhu (skutečné overflow na konkrétním zařízení) nebylo měřeno.*
