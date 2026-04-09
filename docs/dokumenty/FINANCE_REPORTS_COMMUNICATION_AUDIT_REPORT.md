# Hloubkový audit modulů Finance, Reporty a Komunikace

**Datum:** 4. 3. 2025  
**Účel:** Příprava na produkční nasazení – identifikace kapacity, byznys logiky, i18n a kritických oprav.

---

## 1. KAPACITA A VÝKON (zpracování velkých dat)

### 1.1 REPORTY

| Aspekt | Stav | Detail |
|--------|------|--------|
| **Načítání dat** | ❌ Kritické | `reportsDataProvider` (reports_provider.dart) načítá **VŠECHNY** dokončené úkoly tenantu **bez filtru na datum v dotazu**: `.eq('status', 'completed').isFilter('deleted_at', null)`. Žádný `limit`, žádné časové okno v SQL. |
| **Filtrace měsíce** | Po načtení v paměti | Měsíc se aplikuje až v kódu: pro každý úkol se bere `completed_at` / `due_date` / `scheduled_start` a porovná s `startOfMonth`–`startOfNextMonth`. |
| **Riziko** | **Vysoké** | Při 10 000+ dokončených úkolech: jeden obří SELECT, přenos všech řádků, desítky tisíc záznamů v paměti, N+1 dotazy na `reservation_services`, `apartment_services`, `apartment_owners`, `clients`. Reálné riziko pomalého načtení, timeoutu nebo OOM. |
| **Výběr měsíce v UI** | ✅ Ano | Uživatel volí měsíc přes `reportsMonthProvider` (_MonthPicker), ale provider **nevyužívá** tuto hodnotu v dotazu – stáhne celou historii a pak filtruje. |

**Závěr:** Reporty **nemají** povinný filtr na datum na úrovni DB. Celá historie dokončených úkolů se stahuje při každém načtení/změně měsíce. Před produkčním nasazením je nutné přidat **časové okno v dotazu** (např. `completed_at` / `due_date` v rozsahu vybraného měsíce) a zvážit **limit** nebo stránkování pro extrémně velké tenanty.

---

### 1.2 FINANCE

| Komponenta | Načítání | Stránkování / časové okno | Limit |
|------------|----------|----------------------------|--------|
| **Podklady pro fakturaci** (billing) | ❌ Bez datového filtru v DB | Měsíc se vybírá v UI (`BillingMonthParam`), ale **dotaz** na `tasks` je: všechny řádky s `status=completed`, `invoiced_at IS NULL`, `deleted_at IS NULL` – **bez** filtru na `completed_at` v rozsahu měsíce. Filtrace měsíce až v paměti. | Žádný |
| **Zaměstnanecká pokladna** (peněženky) | Stream | — | ✅ **500** peněženek (`watchWalletsRaw`), **500** transakcí celkem (`watchTransactionsRaw`), **200** transakcí na jednu peněženku (`watchTransactionsRawForWallet`) – v `CashWalletRepository`. |
| **Vyúčtování** (settlements) | Závisí na úkolech a payout/commission tabulkách | Fronta „Ke schválení“: data z `adminTasksStreamProvider` (úkoly **omezené na vybraný měsíc** + limit 500 v `watchTasksRawForMonth`). Historie vyplacených: `getPaidSettlementsByMonth` – dotaz na `task_payouts` / `task_commissions` s filtrem na `updated_at` v rozsahu měsíce. | Úkoly: limit 500 na stream (ale bez filtru data v dotazu – viz admin_tasks_repository). Payout/commission dotazy bez explicitního limitu. |

**Poznámka k úkolům ve Finance:**  
`AdminTasksRepository.watchTasksRawForMonth` volá `.stream()...limit(500)` **bez** filtru `scheduled_start`/`due_date` v rozsahu měsíce. Filtrace měsíce probíhá v `_filterAndSort`. To znamená, že se stahuje „posledních 500 úkolů“ (řazení podle `scheduled_start` desc) a z nich se vyberou ty v daném měsíci – u velkých tenantů může být vybraný měsíc mimo těchto 500 a data „chybí“.

**Závěr:**  
- **Podklady pro fakturaci:** Stejný problém jako Reporty – stahování všech nevyfakturovaných dokončených úkolů bez časového okna a bez limitu.  
- **Peněženky a transakce:** Chráněny pevnými limity (500 / 200).  
- **Vyúčtování:** Částečně chráněno (měsíc u historie, u fronty závislost na streamu úkolů s limitem 500, ale bez garantovaného datového filtru v DB).

---

### 1.3 KOMUNIKACE

| Aspekt | Stav | Detail |
|--------|------|--------|
| **Datový zdroj** | Šablony zpráv (tenant_message_templates) | Modul nečerpá z „zpráv“ ani notifikací v reálném čase. Jde o **CRUD šablon** – předpřipravené texty pro řidiče (WhatsApp, placeholdery typu `{guest_name}`, `{flight_number}`). |
| **Načítání** | Jedna request | `messageTemplatesAdminProvider` volá `MessageTemplatesRepository.fetchAll(tenantId)` – jeden `.select()` bez `limit`. |
| **Stránkování / infinite scroll** | ❌ Ne | Žádné stránkování ani lazy loading. Seznam všech šablon se načte najednou. |
| **Riziko** | Nízké až střední | Počet šablon u B2B tenanta bývá řádově desítky. Při stovkách šablon žádný limit nebrání růstu odpovědi. Rozumné je přidat např. limit 200–500 nebo do budoucna stránkování. |

**Závěr:** Komunikace je z hlediska objemu dat v klidu (malý objem), ale z principu by neměla načítat neomezený počet řádků bez limitu nebo stránkování (best practice pro B2B SaaS).

---

## 2. BYZNYS LOGIKA A EXPORTY

### 2.1 PDF A OCHRANA PROTI NULL / SMAZANÝM ENTITÁM

| Export | Soubor | Ochrana proti null / smazaným |
|--------|--------|--------------------------------|
| **Billing PDF** (podklady pro fakturaci) | `billing_pdf_service.dart` | **Client:** `group.groupName` – z `BillingGroup` (groupKey/clientId → jméno z mapování při buildi; pro `external` se bere `externalDisplayName` z parametrů). Smazaný klient by v „živých“ podkladech neměl figurovat (group se buduje z aktuálních úkolů a mapování klientů). **Guest:** `first.guestName` – kontroluje se `!= null && isNotEmpty`, jinak fallback na `labelReservation$shortId`. **Datum:** použití `scheduledStart` / `completedAt` s null check. **Obrázky:** každá URL v try-catch, selhání jedné fotky neshodí celé PDF. |
| **Settlement export PDF** (vyúčtování) | `settlement_export_service.dart` | **Příjemce:** `PayoutGroup.recipientName` – v `settlements_provider.dart` se u zaměstnanců při prázdném jménu z profilu používá `common.removed_user`.tr(), u partnerů (client) `name.isEmpty ? '—' : name`. V PDF se tedy neskončí úplně prázdným řádkem. **Měsíc v hlavičce:** `monthLabel ?? DateFormat.yMMMM('cs_CZ').format(month)` – při null `monthLabel` je **pevně** cs_CZ. |

**Rizika:**  
- Billing PDF spoléhá na to, že `BillingGroup` vždy obsahuje vyplněné `groupName`; pokud by se někde předalo prázdné jméno pro reálného klienta, v PDF by byl prázdný řetězec – v současném toku dat by k tomu nemělo docházet.  
- Settlement PDF je na null/smazané příjemce připraven (fallbacky).  
- **cs_CZ** v Settlement exportu je hardcoded fallback – viz sekce i18n.

### 2.2 KOMUNIKACE – BYZNYS LOGIKA A B2B BEST PRACTICES

- **Funkce:** Vytváření, úprava, mazání šablon zpráv; řazení podle `order_index`, jazyka a názvu. Placeholdery řeší `template_placeholder_service.dart`.  
- **Chybějící / doporučené:**  
  - Žádná auditní stopa (kdo kdy šablonu vytvořil/upravil).  
  - Žádné rate limiting ani ochrana proti hromadnému vytváření šablon (např. limit na počet šablon na tenanta).  
  - Chybové hlášky z notifieru (`StateError('Žádný tenant…')`, `StateError('Tenant ID je povinný…')`) jsou **natvrdo česky** – viz sekce i18n.

---

## 3. i18n A HARDCODED TEXTY

### 3.1 REPORTY

- **UI:** Používá i18n klíče (`admin.menu_reports`, `admin.reports_month_format`, `admin.reports_total_revenue` atd.).  
- **Chyby:** `err.toString()` v error stavu – zobrazení surové výjimky; pokud někde v řetězci reportů vyleze `StateError` nebo český text, uživatel uvidí češtinu.  
- **Formát měsíce:** `admin.reports_month_format` s `month`/`year` – závisí na překladu, v kódu není natvrdo CZ.

### 3.2 FINANCE

| Místo | Typ | Text / poznámka |
|-------|-----|------------------|
| **settlement_export_service.dart** | PDF fallbacky | Všechny default labely v češtině: `'Vyúčtování odměn a provizí'`, `'Jméno příjemce'`, `'Typ'`, `'Částka celkem'`, `'Celkem vyplaceno'`, `'Zaměstnanec'`, `'Partner'`. |
| **settlement_export_service.dart** | Formát data | `monthLabel ?? DateFormat.yMMMM('cs_CZ').format(month)` – při chybějícím `monthLabel` je **vždy** český formát měsíce. |
| **billing_pdf_service.dart** | PDF fallbacky | Anglické: `'Services report for '`, `'Client: '`, `'Executive Summary'`, … (slouží jako fallback, když `footerLabels` nejsou předány). Volající (owner_billing_screen, finance_billing_screen) předávají mapy z i18n. |
| **finance_cash_provider.dart** | Fallback jména | `'common.removed_user'.tr()` – korektně i18n. |
| **settlements_provider.dart** | StateError | `'Nelze schválit vyúčtování bez tenant ID.'` – česky natvrdo. |
| **finance_billing_provider** | Komentáře | Pouze komentáře v kódu (česky), ne runtime text. |

### 3.3 KOMUNIKACE

| Místo | Typ | Text |
|-------|-----|------|
| **message_templates_admin_provider.dart** | StateError (create/update/delete) | `StateError('Žádný tenant v kontextu.')` – 3× stejný text. |
| **message_templates_repository.dart** | StateError | `StateError('Tenant ID je povinný pro vytvoření šablony.')`, `StateError('Tenant ID je povinný pro úpravu šablony.')` – volající může zobrazit uživateli, tedy čeština v UI. |
| **communication_templates_screen.dart** | UI | Pouze i18n klíče (`communication.title`, `communication.subtitle`, `common.error_with_message`, …). |

### 3.4 OSTATNÍ ADMIN (pro kontext)

- **clients_provider.dart:** řada `StateError` v češtině (`'Žádný tenant v kontextu.'`, `'Klient musí patřit…'`, `'Nelze smazat klienta…'`).  
- **admin_dashboard_screen.dart:** `'Dnes'` natvrdo v popisku osy grafu (line chart).  
- **admin_tasks_repository / admin_tasks_provider:** komentáře a např. `StateError('Missing tenant_id')` (anglicky), parsování data `DateFormat('dd.MM.yyyy')` bez locale.

**Závěr:** V modulech Finance, Reporty a Komunikace jsou hlavní problémy: **české StateError zprávy** v providerech a repozitářích, **české fallbacky a pevný cs_CZ** v Settlement exportu PDF a **jedno hardcoded „Dnes“** na dashboardu (související s reporty/grafy).

---

## 4. DOPORUČENÍ – NEJKritičtĚJŠÍ OPRAVY PŘED PRODUKCÍ

### REPORTY (1–2 kritické)

1. **Povinný filtr na datum v DB a omezení objemu dat**  
   V `reportsDataProvider` neprovádět jeden dotaz na všechny dokončené úkoly. Přidat do dotazu na `tasks` filtr na vybraný měsíc (např. `completed_at` mezi `startOfMonth` a `startOfNextMonth`, s fallbackem na `due_date`/`scheduled_start` dle stávající logiky). Případně přidat rozumný `limit` (např. 2000) jako pojistku. Tím se odstraní riziko pádu/timeoutu při 10 000+ úkolech.

2. **Lokalizace chyb a zobrazení chyb uživateli**  
   Místo `err.toString()` v error stavu Reporty obrazovky zobrazit uživatelsky srozumitelnou zprávu z i18n (např. `admin.reports_load_error`) a technický detail pouze v debug režimu. Zabrání se tak zobrazení českých `StateError` nebo stack trace koncovému uživateli.

---

### FINANCE (1–2 kritické)

1. **Podklady pro fakturaci – časové okno v dotazu**  
   V `billingReportProvider` (finance_billing_provider.dart) při načítání „živých“ dat nevolat dotaz na všechny dokončené nevyfakturované úkoly bez omezení. Přidat filtr na `completed_at` (nebo fallback `due_date`/`scheduled_start`) v rozsahu `param.year`/`param.month` přímo v dotazu. Tím se výrazně sníží objem dat a zátěž DB i klienta.

2. **Settlement export PDF – i18n a datum**  
   V `settlement_export_service.dart`: (a) Všechny fallback labely (report_title, col_name, col_type, …) buď úplně odstranit a vynutit předání `labels` z volajícího (který použije i18n), nebo nahradit anglickými / klíči. (b) Místo `DateFormat.yMMMM('cs_CZ')` použít např. `DateFormat.yMMMM(locale)` s locale z kontextu nebo z parametru, aby export nebyl v produkci vždy v češtině.

---

### KOMUNIKACE (1–2 kritické)

1. **StateError a repository chyby – i18n**  
   V `message_templates_admin_provider.dart` a `message_templates_repository.dart` nahradit všechny české `StateError` buď kódy (a v UI mapovat na i18n zprávy), nebo přímo klíči pro `.tr()` při zobrazení uživateli. Např. `communication.error_no_tenant`, `communication.error_tenant_required` – a doplnit do cs.json, en.json, es.json.

2. **Limit počtu šablon**  
   V `MessageTemplatesRepository.fetchAll` přidat `.limit(500)` (nebo konfigurovatelné maximum) a v UI při dosažení limitu zobrazit informaci, že nelze přidat další šablonu bez smazání starších. U větších tenantů přidat do budoucna stránkování nebo lazy loading. Tím se dodrží best practice „nikdy nenačítat neomezený počet záznamů“.

---

## Shrnutí tabulkou

| Modul        | Kapacita / výkon                          | PDF / null ochrana              | i18n / hardcoded                          | Priorita oprav |
|-------------|--------------------------------------------|----------------------------------|--------------------------------------------|----------------|
| **Reporty** | ❌ Celá historie úkolů, bez limitu          | N/A (žádný PDF)                  | Error zprávy mohou být česky                | 1. Datum v DB, 2. i18n chyb |
| **Finance** | ❌ Billing bez datového filtru; pokladna OK | ✅ Fallbacky u příjemců; ⚠️ cs_CZ | ❌ České fallbacky v Settlement PDF + cs_CZ | 1. Billing datum v DB, 2. PDF i18n + locale |
| **Komunikace** | ⚠️ fetchAll bez limitu                    | N/A                              | ❌ StateError česky v provideru i repository | 1. i18n chyb, 2. Limit šablon |

Tento dokument slouží jako podklad pro plánování úprav před produkčním nasazením; implementační detaily a konkrétní úpravy kódu je vhodné řešit v navazujících úkolech.
