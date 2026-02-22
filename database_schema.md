# FalcoNest – Oficiální schéma databáze

> **Pravidlo:** Při generování SQL dotazů, RLS politik nebo Dart modelů (.fromJson) vždy nejdříve zkontroluj tento soubor a ověř přesné názvy sloupců a datové typy. Nikdy nehádej názvy sloupců.

---

| Tabulka | Sloupec | Typ dat | Může být NULL? |
|---------|---------|---------|----------------|
| zones | id | uuid | NO |
| zones | tenant_id | uuid | NO (FK → tenants) |
| zones | name | text | NO |
| zones | created_at | timestamp with time zone | YES |
| zones | deleted_at | timestamp with time zone | YES – Soft delete; NULL = aktivní |
| apartment_owners | id | uuid | NO |
| apartment_owners | apartment_id | uuid | NO |
| apartment_owners | owner_id | uuid | NO |
| apartment_owners | deleted_at | timestamp with time zone | YES – Soft delete; NULL = aktivní |
| apartments | id | uuid | NO |
| apartments | tenant_id | uuid | NO |
| apartments | name | text | NO |
| apartments | address | text | YES |
| apartments | keybox | text | YES |
| apartments | status | text | YES |
| apartments | check_in_time | text | YES |
| apartments | check_out_time | text | YES |
| apartments | standard_cleaning_duration | integer | YES |
| apartments | owner_notes | text | YES |
| apartments | zone_id | uuid | YES (FK → zones) – oblast, do které apartmán patří |
| apartments | deleted_at | timestamp with time zone | YES |
| app_super_admins | id | uuid | NO |
| audit_logs | id | uuid | NO |
| audit_logs | tenant_id | uuid | YES |
| audit_logs | user_id | uuid | YES |
| audit_logs | action_type | text | NO |
| audit_logs | table_name | text | YES |
| audit_logs | record_id | text | YES |
| audit_logs | details | jsonb | YES |
| audit_logs | created_at | timestamp with time zone | NO |
| currencies | code | text | NO |
| currencies | symbol | text | NO |
| currencies | rate | numeric | NO |
| currencies | name | text | YES |
| currencies | created_at | timestamp with time zone | YES |
| invitations | id | uuid | NO |
| invitations | email | text | NO |
| invitations | tenant_id | uuid | NO |
| invitations | role | text | NO |
| invitations | first_name | text | NO |
| invitations | last_name | text | NO |
| invitations | created_at | timestamp with time zone | YES |
| invitations | roles | ARRAY | YES |
| invitations | start_date | text | YES |
| invitations | end_date | text | YES |
| invitations | weekly_hours | integer | YES |
| invitations | profile_id | uuid | YES |
| modules | id | uuid | NO |
| modules | key | text | NO |
| modules | name | text | NO |
| modules | description | text | YES |
| modules | price_eur | numeric | YES |
| modules | created_at | timestamp with time zone | YES |
| modules | order_index | integer | YES |
| modules | pricing_type | text | NO |
| modules | show_in_menu | boolean | NO (default true) |
| modules | parent_module_key | text | YES |
| profiles | id | uuid | NO |
| profiles | auth_id | uuid | YES |
| profiles | email | text | YES |
| profiles | first_name | text | YES |
| profiles | last_name | text | YES |
| profiles | name | text | YES |
| profiles | status | text | NO |
| profiles | tenant_id | uuid | YES |
| profiles | role | text | YES |
| profiles | roles | ARRAY | YES |
| profiles | weekly_hours | integer | YES |
| profiles | start_date | date | YES |
| profiles | end_date | date | YES |
| profiles | zone_preferences | jsonb | YES (default '{}') – žebříček preferencí oblastí: {"zone_id": 1, ...}. 1 = nejraději |
| profiles | language_code | text | YES |
| profiles | preferred_currency | text | YES |
| profiles | last_sign_in_at | timestamp with time zone | YES |
| profiles | created_at | timestamp with time zone | YES |
| profiles | updated_at | timestamp with time zone | YES |
| profiles | deleted_at | timestamp with time zone | YES |
| reservations | id | uuid | NO |
| reservations | apartment_id | uuid | NO |
| reservations | start_date | date | NO |
| reservations | end_date | date | NO |
| reservations | special_requests | text | YES |
| reservations | guest_name | text | YES |
| reservations | check_in | text | YES |
| reservations | check_out | text | YES |
| reservations | needs_transfer | boolean | YES |
| reservations | status | text | YES |
| reservations | tenant_id | uuid | YES |
| reservations | deleted_at | timestamp with time zone | YES |
| reservations | guest_adults | integer | NO (default 0) |
| reservations | guest_children | integer | NO (default 0) |
| reservations | arrival_time | timestamp with time zone | YES |
| reservations | guest_phone | text | YES – telefon hosta (pro transfery a předání) |
| reservations | reservation_source | text | YES (default 'Other', CHECK: 'Booking', 'Airbnb', 'Direct', 'Other') – zdroj rezervace |
| reservations | departure_time | timestamp with time zone | YES – předpokládaný čas odjezdu (pro Task Automator: úklid, transfer na letiště) |
| reservations | internal_note | text | YES – interní poznámka manažera. Not synced to mobile app, for admin dashboard only. |
| staff_absences | id | uuid | NO |
| staff_absences | profile_id | uuid | YES |
| staff_absences | start_date | text | NO |
| staff_absences | end_date | text | NO |
| staff_absences | reason | text | YES |
| staff_absences | invitation_id | uuid | YES |
| staff_absences | tenant_id | uuid | YES |
| tasks | id | uuid | NO |
| tasks | tenant_id | uuid | NO |
| tasks | apartment_id | uuid | NO |
| tasks | assigned_user_id | uuid | YES |
| tasks | scheduled_start | timestamp with time zone | NO |
| tasks | status | text | NO |
| tasks | photo_url | text | YES |
| tasks | local_updated_at | timestamp with time zone | NO |
| tasks | assigned_to | uuid | YES |
| tasks | task_type | text | YES |
| tasks | due_date | text | YES |
| tasks | description | text | YES |
| tasks | title | text | YES |
| tasks | deleted_at | timestamp with time zone | YES |
| tasks | reservation_id | uuid | YES (FK → reservations ON DELETE CASCADE) – vazba na rezervaci, pro mazání při změně termínu |
| tasks | service_id | uuid | YES (FK → tenant_services ON DELETE SET NULL) – vazba na službu; pro scheduled úkoly a ochranný štít |
| tenant_modules | id | uuid | NO |
| tenant_modules | tenant_id | uuid | YES |
| tenant_modules | module_id | uuid | YES |
| tenant_modules | status | text | YES |
| tenant_modules | valid_until | timestamp with time zone | YES |
| tenant_modules | created_at | timestamp with time zone | YES |
| tenant_modules | is_trial | boolean | NO (default false) |
| tenant_modules | trial_ends_at | timestamp with time zone | YES |
| tenant_modules | deleted_at | timestamp with time zone | YES – Soft delete; NULL = aktivní |
| tenant_modules | stripe_subscription_id | text | YES – ID opakovaného předplatného ve Stripe pro tento modul |
| tenant_modules | stripe_price_id | text | YES – ID cenového plánu ve Stripe (měsíční/roční) |
| tenant_modules | cancel_at_period_end | boolean | NO (default false) – zrušeno, předplatné doběhne do valid_until |
| tenants | id | uuid | NO |
| tenants | name | text | NO |
| tenants | notes | text | YES |
| tenants | is_active | boolean | YES |
| tenants | trial_ends_at | date | YES |
| tenants | paid_until | timestamp with time zone | YES – Zaplaceno do / Kill Switch; přístup blokován pokud today > paid_until |
| tenants | system_announcement | text | YES |
| tenants | discount_percentage | integer | NO (default 0, CHECK 0–100) |
| tenants | deleted_at | timestamp with time zone | YES – Soft delete; NULL = aktivní |
| tenants | stripe_customer_id | text | YES – ID zákazníka ve Stripe pro fakturaci |
| tenants | billing_email | text | YES – e-mail pro odesílání faktur (může být jiný než majitel) |
| invoices | id | uuid | NO |
| invoices | tenant_id | uuid | NO (FK → tenants) |
| invoices | stripe_invoice_id | text | YES – ID faktury ve Stripe |
| invoices | amount_due | numeric | NO – částka k úhradě |
| invoices | amount_paid | numeric | NO – zaplacená částka |
| invoices | currency | text | NO (default 'eur') |
| invoices | status | text | NO – draft, open, paid, uncollectible, void |
| invoices | invoice_pdf_url | text | YES – odkaz na stažení PDF (Stripe nebo náš systém) |
| invoices | created_at | timestamp with time zone | NO |
| invoices | paid_at | timestamp with time zone | YES – kdy byla faktura zaplacena |
| tenant_wallets | tenant_id | uuid | NO (PK, FK → tenants) – jeden řádek na tenanta, předplacená peněženka kreditů. Záznamy vznikají automaticky pomocí triggeru AFTER INSERT na tabulce tenants. |
| tenant_wallets | balance | integer | NO (default 0) – aktuální stav kreditů |
| tenant_wallets | updated_at | timestamp with time zone | YES (default now()) |
| wallet_transactions | id | uuid | NO |
| wallet_transactions | tenant_id | uuid | NO (FK → tenants) – účetní kniha, append-only |
| wallet_transactions | amount | integer | NO – kladné (dobití), záporné (útrata) |
| wallet_transactions | transaction_type | text | NO – např. 'TOP_UP', 'USAGE_AUTO_TASKS' |
| wallet_transactions | reference_id | text | YES – vazba na Stripe payment ID nebo log generování |
| wallet_transactions | created_at | timestamp with time zone | YES (default now()) |
| tenant_services | id | uuid | NO |
| tenant_services | tenant_id | uuid | NO |
| tenant_services | name | text | NO |
| tenant_services | description | text | YES |
| tenant_services | service_type | text | NO – code odpovídající task_categories (cleaning, transfer_in, check_in, …). Validace v aplikační vrstvě. |
| tenant_services | default_price | numeric | YES |
| tenant_services | is_active | boolean | NO (default true) |
| tenant_services | deleted_at | timestamp with time zone | YES |
| tenant_services | order_index | integer | YES (default 0) |
| tenant_services | required_role | text | YES (default 'any') – požadovaná profese: any, cleaner, driver, maintenance, checkin_agent (pro Task Automator) |
| tenant_services | duration_minutes | integer | YES (default 60) – časová náročnost / rezerva v minutách. U úklidu vata nad standardCleaningDuration, u transfer/extra fixní doba |
| apartment_services | id | uuid | NO |
| apartment_services | tenant_id | uuid | NO |
| apartment_services | apartment_id | uuid | NO |
| apartment_services | service_id | uuid | NO (FK → tenant_services) |
| apartment_services | custom_price | numeric | YES |
| apartment_services | custom_description | text | YES |
| apartment_services | trigger_type | text | NO. CHECK: povolené hodnoty pouze **'on_demand'**, **'before_checkin'**, **'after_checkout'**, **'both_ways'**, **'scheduled'**. Hodnota 'manual' je zrušena (migrace přepisuje na 'on_demand'). Spouštěč pro Task Automator. |
| apartment_services | schedule_interval | text | YES. CHECK: povolené hodnoty **NULL** nebo **'1_week'**, **'2_weeks'**, **'1_month'**, **'2_months'**, **'3_months'**, **'6_months'**. Staré hodnoty (weekly, monthly, biweekly, biannually) jsou migrací přepsány na NULL. Pouze u trigger_type = 'scheduled' se interval používá pro pravidelnou údržbu. |
| apartment_services | is_mandatory | boolean | NO (default false) – pokud true, nelze v rezervaci odškrtnout |
| apartment_services | payer_type | text | NO (default 'guest', CHECK: 'owner', 'guest') – kdo platí službu (majitel / host) |
| reservation_services | id | uuid | NO |
| reservation_services | tenant_id | uuid | NO |
| reservation_services | reservation_id | uuid | NO (FK → reservations) |
| reservation_services | apartment_service_id | uuid | NO (FK → apartment_services) |
| reservation_services | custom_note | text | YES |
| reservation_services | charged_price | numeric | YES |
| reservation_services | payer_type | text | YES (CHECK: 'owner', 'guest') – kdo platí u této rezervace (override) |
| task_categories [GLOBAL DICTIONARY] | id | uuid | NO |
| task_categories | code | text | NO – systémový klíč, UNIQUE, např. 'cleaning', 'transfer_in' |
| task_categories | color_hex | text | NO – HEX barva pozadí, např. '#FFF3E0' |
| task_categories | icon_name | text | YES – název Material Icons ikony, např. 'directions_car', 'key' |
| task_categories | order_index | integer | YES (default 0) – pořadí v legendě a dropdownu |

---

### Tabulka task_categories [GLOBAL DICTIONARY] – globální číselník typů úkolů

Tabulka **task_categories** je **platformový globální číselník** typů úkolů. Na rozdíl od per-tenant tabulek zde **chybí sloupec tenant_id** – kategorie jsou sdílené pro celou platformu a spravuje je majitel FalcoNestu. To zjednodušuje onboarding nových agentur: nemusejí definovat vlastní kategorie, dostanou jednotnou výchozí sadu.

**Proč chybí tenant_id a name:**
- **tenant_id** – kategorie nejsou vázané na agenturu; jsou globální.
- **name** – zobrazované názvy se **nelokalizují v DB**. Lokalizace probíhá výhradně přes i18n JSON soubory (např. `admin.task_type_cleaning`). Databáze uchovává pouze logiku: kódy, barvy a ikony.

**Sloupce:**
- **id** – UUID primární klíč
- **code** – systémový klíč (UNIQUE), např. `cleaning`, `transfer_in`, `check_in`; mapuje se na `tasks.task_type` a `tenant_services.service_type`
- **color_hex** – barva pozadí karty v HEX formátu
- **icon_name** – název Material Icons ikony
- **order_index** – pořadí v legendě a dropdownu

**RLS politiky:**
- **SELECT** – všichni autentizovaní uživatelé (s platným profilem v `public.profiles`) mohou číst.
- **INSERT, UPDATE, DELETE** – pouze Super Admin (`public.is_super_admin()`).

**Napojení:** Úkoly (`tasks.task_type`) a služby (`tenant_services.service_type`) používají hodnoty odpovídající sloupci `code`. Flutter mapuje `code` na i18n klíč `admin.task_type_{code}` pro lokalizovaný název.

---

### Soft delete (deleted_at)

U tabulek **tasks**, **apartments**, **profiles**, **reservations**, **tenant_services**, **zones**, **apartment_owners**, **tenants** a **tenant_modules** sloupec **deleted_at** (timestamptz, nullable) znamená „měkké smazání“: místo fyzického DELETE se volá UPDATE s `deleted_at = now()`. Záznamy s `deleted_at IS NOT NULL` aplikace při načítání vynechává (filtr `.is_('deleted_at', null)`). Audit záznam (SOFT_DELETE) se zapisuje do `audit_logs`.

---

### Prepaid Wallet (Předplacená peněženka) – kredity pro prémiové moduly

Systém **tenant_wallets** + **wallet_transactions** slouží pro předplacené kredity (např. generování úkolů přes automatizaci). Klienti si kupují balíčky kreditů; každé použití (např. „Generovat návrhy úkolů“) strhne určitý počet kreditů.

**Princip:**
- **tenant_wallets** – jeden řádek na tenanta; sloupec `balance` drží aktuální stav kreditů. Záznamy vznikají automaticky pomocí triggeru `trg_tenant_wallet_after_insert` (AFTER INSERT) na tabulce `tenants`; stávající tenanty doplňuje zpětně migrace (backfill).
- **wallet_transactions** – append-only účetní kniha; každá změna (dobití TOP_UP, útrata USAGE_AUTO_TASKS) vytvoří nový záznam s kladnou nebo zápornou částkou.

**Bezpečnost a Race Condition:**
- Klient (admin, manager) smí **pouze číst** (SELECT) vlastní peněženku a transakce – zákaz INSERT/UPDATE z aplikace!
- Jakékoli stržení kreditů probíhá **výhradně přes RPC funkci** `deduct_wallet_credits()`, která používá zámek řádku (`FOR UPDATE`) pro ochranu proti souběhu (více dispečerů generuje úkoly současně).
- Doplňování kreditů (TOP_UP) provádí Super Admin nebo Stripe webhook přes service_role / SECURITY DEFINER funkci.

**RLS:** Role admin a manager smí pouze SELECT vlastní data; super_admin a service_role mají plná práva. Na tenant_wallets není povolena přímá INSERT/UPDATE pro běžné uživatele.

---

### Registr modulů (modules.key) – reference

- **automatic_tasks** – Feature flag / sub-modul patřící k modulu `tasks`. Odemkne premium funkce na obrazovce Úkoly (Generovat návrhy, Přepočítat personál). Nemá vlastní obrazovku: v tabulce `modules` má `show_in_menu = false` a `parent_module_key = 'tasks'`. V Super Admin Tenant Detail se zobrazuje s lokalizovaným názvem a ikonou díky `ModuleIconMapper` (ikona: auto_awesome, label: admin.menu_automatic_tasks).

---

### 3-úrovňový model dynamických služeb (Override Pattern)

Služby jsou definovány na třech úrovních: **Katalog agentury** → **Ceník/pravidla bytu** → **Služby vybrané k pobytu**. Cena a popis se na každé úrovni mohou **přepsat** (override); pokud není přepis zadaný, použije se hodnota z úrovně nadřazené.

| Úroveň | Tabulka | Cena | Popis / poznámka | Plátce |
|--------|---------|------|------------------|--------|
| 1. Katalog | **tenant_services** | `default_price` – výchozí cena služby v rámci tenanta | `description` – co služba standardně obsahuje | – |
| 2. Byt | **apartment_services** | `custom_price` – přepis ceny pro tento byt (NULL = použít výchozí z katalogu) | `custom_description` – přepis obsahu pro tento byt (NULL = použít z katalogu) | `payer_type` – výchozí plátce: 'owner' (majitel – faktura) nebo 'guest' (host – na místě) |
| 3. Rezervace | **reservation_services** | `charged_price` – skutečně účtovaná cena za tuto službu u této rezervace (NULL = dopočítat z bytu/katalogu) | `custom_note` – **specifická poznámka klienta k této jedné službě** (např. „Potřebujeme dětskou sedačku“ u transferu, „Přivézt pivo místo vína“ u balíčku). **Poznámky ke službám nepatří do reservations**, pouze sem. | `payer_type` – kdo platí u tohoto pobytu (NULL = použít z apartment_services) |

**Kaskádové přepisování (Override Pattern):**

- **Cena:** Aplikace při zobrazení/účtování bere v pořadí: `reservation_services.charged_price` → pokud NULL, pak `apartment_services.custom_price` → pokud NULL, pak `tenant_services.default_price`.
- **Popis obsahu služby:** Aplikace bere v pořadí: `apartment_services.custom_description` → pokud NULL, pak `tenant_services.description`. Pole `reservation_services.custom_note` je **pouze poznámka klienta** k této konkrétní službě u pobytu, ne přepis oficiálního popisu.
- **Plátce služby (kdo platí):** Na úrovni bytu se nastaví výchozí `apartment_services.payer_type` (majitel vs. host). U konkrétní rezervace lze přepsat v `reservation_services.payer_type`; pokud je NULL, použije se hodnota z bytu.

**Poznámka k rezervacím:** Textové poznámky ke konkrétním službám (co klient chce u transferu, u úklidu atd.) se ukládají výhradně do **reservation_services.custom_note**. Do tabulky **reservations** se nepřidávají žádná další textová pole pro služby; rozšíření rezervace jsou sloupce **guest_adults**, **guest_children** (počty hostů) a **arrival_time** (předpokládaný čas příjezdu).
