# FalcoNest – technický audit Admin systému

Rozsah: `lib/features/admin/`, `lib/core/` (související s admin datovými toky), Drift balíček, `supabase/migrations/`.  
Stav: ✅ OK · ⚠️ varování / technický dluh · ❌ kritické (z pohledu pravidel projektu).

---

## 1. MULTI-TENANT & RLS

### 1.1 Sloupec `tenant_id`

- ✅ **Globální katalogy bez `tenant_id` (záměr):** `modules`, `currencies` – definice v `20250225_tenant_modules_and_modules.sql`, `20250301_currencies_and_modules_price_eur.sql`.
- ⚠️ **Vazební / odvozená data bez vlastního `tenant_id`:** `user_roles` – pouze `profile_id` + `role`; izolace přes join na `profiles.tenant_id` a RLS (`20250216_user_roles.sql`).
- ✅ **`profiles`:** multi-tenant přes `tenant_id` (nullable u ghost/HQ scénářů) – `20250306_unified_profiles_ghost_strategy.sql`.
- ✅ **Konfigurace bez tenant scope pro klienta:** `cron_edge_config` – žádný tenant sloupec; RLS bez politik pro `authenticated` = aplikace nemá přístup; backend/cron přes service role (`20260319100000_fix_security_advisor.sql`, `20260231220000_template_reminders_notifications.sql`).

### 1.2 RLS (`ENABLE ROW LEVEL SECURITY`)

- ✅ Migrace opakovaně zapínají RLS na klíčových tabulkách (`20250218_rls_multi_tenant.sql` a navazující soubory; výčet v grep výsledcích: `tasks`, `reservations`, `apartments`, `tenants`, `profiles`, finance, automations, settlements, …).
- ✅ **Security Advisor oprava:** `invitations` + `cron_edge_config` – `20260319100000_fix_security_advisor.sql`.
- ⚠️ **Úplná stoprocentní kontrola „každá tabulka v DB“:** v repozitáři je historie lineárních migrací; audit neprováděl automatický diff „CREATE TABLE vs. ENABLE RLS“ nad produkčním `information_schema`. Riziko opomenutí u tabulek vytvořených mimo tento git stav = nenulové.

### 1.3 Politiky a `my_tenant_id()`

- ✅ Novější politiky konzistentně používají `public.my_tenant_id()` / `public.is_super_admin()` (např. `20260308000000_create_settlements_and_commissions.sql`, `20260302000000_client_addresses.sql`, `20250312_reservations_rls_insert.sql`).
- ⚠️ **Starší `user_roles`:** politiky používají přímé porovnání přes `profiles` a `auth.uid()`, ne vždy jednotný vzor `my_tenant_id()` (`20250216_user_roles.sql`).

### 1.4 Dart: obcházení RLS / filtrace na klientu

- ✅ **`SupabaseService.safeFrom` + `safeInsertPayload`:** dokumentovaná „Frontend Firewall“ proti super-admin přístupu ke všem tenantům bez filtru – `lib/core/services/supabase_service.dart`.
- ⚠️ **`SupabaseService.client.from(...)` + ruční `.eq('tenant_id', tenantId)`** místo `safeFrom`: široce v admin vrstvě – **stejné chování pro běžného admina**, ale **u přihlášeného super admina bez `tenantIdForData` / při chybě filtru hrozí širší SELECT než zamýšlené UI** (RLS povolí; aplikace spoléhá na `.eq`).
  - `lib/features/admin/providers/finance_billing_provider.dart` (řetězce dotazů na `billing_snapshots`, `clients`, `apartments`, `apartment_owners`, `tasks`, …).
  - `lib/features/admin/providers/reports_provider.dart` (řádky cca 138–149, 186–190, 231–235, 248–270 – mimo jiné `apartment_owners` bez explicitního `tenant_id` ve filtru; spoléhá na RLS).
  - `lib/features/admin/premium_upsell_dialog.dart` (`tenant_modules` – update/insert s `.eq('tenant_id', tenantId)`).
  - `lib/features/admin/providers/apartment_owners_provider.dart` (mimo jiné `client.from('apartment_owners')`).
  - `lib/features/admin/providers/clients_provider.dart` (`client.from('profiles')` pro portal status).
  - `lib/features/admin/providers/module_provider.dart`, `current_tenant_name_provider.dart` (`tenants`, `tenant_modules`, `modules` – část záměrně globální / katalog).
- ❌ **Kritické riziko záměnu identity při zápisu:** `lib/features/admin/admin_team_screen.dart` – mazání/úprava přes `SupabaseService.client.from('profiles').update(...).eq('id', ...)` **bez** `safeFrom` (řádky cca 402–424, 1631+, 2291+). RLS musí striktně omezit zápis; pokud by politika na `profiles` selhala nebo byla příliš široká, jde o přímý vektor útoků na cizí profily podle ID.
- ⚠️ **Widget s přímým Supabase:** `lib/features/admin/admin_reservation_forms.dart` – `_loadServicesState`: `SupabaseService.client.from('apartments').select('tenant_id')` pro owner flow (cca ř. 1391–1396). Obcházení RLS není; jde o načtení tenant_id podle ID bytu.

---

## 2. OFFLINE-FIRST A SYNCHRONIZACE

### 2.1 Drift (lokální DB)

- ✅ **Implementace:** `packages/falconest_drift/lib/app_database.dart` – tabulky: `Tasks`, `Apartments`, `Clients`, `Reservations`, `Tenants`, `MessageTemplates`, `PendingMutations`, `PendingAuditActions`.
- ⚠️ **Admin modul není plně offline-first:** providery (`admin_tasks_provider`, `admin_reservations_provider`, `finance_billing_provider`, `reports_provider`, …) primárně čtou/zapisují **Supabase** přes síť. Drift je dokumentován jako paralelní cesta zejména pro Worker / mobilní stabilitu (`lib/core/database/drift/database_provider.dart`).
- ⚠️ **Parita schématu:** Drift `Tasks` nemá sloupce jako `deleted_at` v tabulce úkolů (viz definice `Tasks` v `app_database.dart`); soft delete a fakturační stavy žijí v Supabase modelu. Admin agregace vždy bere živá data z networku.

### 2.2 `updated_at` / `deleted_at` (UTC)

- ✅ **Supabase:** migrace a komentáře opakovaně definují soft delete (`deleted_at`) a triggery `updated_at` na vybraných tabulkách (např. `20250402_soft_delete_zones_owners_tenants.sql`, zmínky u `tasks` v migracích).
- ⚠️ **Drift:** `localUpdatedAt` / `lastUpdated` – slouží k merge, ne vždy 1:1 se serverovým `updated_at` u všech entit v admin UI.

### 2.3 Repozitáře čtoucí „přímo“ Supabase

- ✅ **Záměr pro Admin dashboard:** Realtime a reporty – např. `lib/features/admin/providers/admin_tasks_repository.dart` (`watchTasksRaw` + `safeFrom('tasks', tenantId)`).
- ⚠️ **Bez Drift vrstvy:** většina `lib/features/admin/providers/*.dart` a část `*_screen.dart` – přímé dotazy jak výše; **není porušení RLS samo o sobě**, ale **porušení pravidla „read local first“** pro admin část aplikace.

---

## 3. I18N (natvrdo v UI)

Pravidlo: žádné uživatelské řetězce mimo lokalizaci. Níže **konkrétní výskyty** (ne technické symboly jako oddělovač „·“ v core widgetu – lze považovat za neutrální, ale uvádíme pro úplnost).

| Stav | Soubor | Řádky / poznámka |
|------|--------|------------------|
| ⚠️ | `lib/features/admin/admin_apartments_screen.dart` | 1326, 2151: `Text('—')` (placeholder výběru); 1329, 2154: `Text('$y')` (rok – obsah ne z i18n). |
| ⚠️ | `lib/features/admin/admin_reservation_forms.dart` | 820, 851, 2042, 2073: `hintText: 'HH:mm'` (formát času jako pevný řetězec). |
| ⚠️ | `lib/features/admin/widgets/settlement_split_dialog.dart` | 384: `content: Text('$e')` – výjimka bez lokalizované šablony. |
| ⚠️ | `lib/features/admin/admin_reservations_screen.dart` | 579: `SnackBar(content: Text(key.startsWith('admin.') ? key.tr() : key))` – pokud `key` není klíč, zobrazí se surový řetězec. |
| ⚠️ | `lib/core/widgets/sms_counter_text_field.dart` | 44, 52: `Text('·')` – oddělovač (ne jazykový text). |

- ⚠️ **Formátování datumů:** `DateFormat('d.M. HH:mm')`, `DateFormat('HH:mm')` atd. v admin souborech – **nejsou překlady věty**, ale **pevné locale vzory** (`admin_automations_screen.dart`, `admin_layout.dart`, `admin_tasks_screen.dart`, …). Riziko: nekonzistence s locale pravidly uživatele.

- ✅ **PDF služby (`lib/core/services/billing_pdf_service.dart` atd.):** generují dokumenty s dynamickými hodnotami – mimo rozsah „admin UI widget“, ale pokud PDF má být vícejazyčné, kontrola labelů zvlášť.

---

## 4. STATE MANAGEMENT A CLEAN ARCHITECTURE (Riverpod)

### 4.1 Byznys logika / Supabase ve widgetech

- ⚠️ **`admin_team_screen.dart`:** přímé volání `SupabaseService.client` v dialogu mazání člena + další operace (viz sekce 1.4).
- ⚠️ **`admin_apartments_screen.dart`, `admin_reservations_screen.dart`, `admin_tasks_screen.dart`:** transakční operace (mazání, kaskády) s `SupabaseService.safeFrom` / `client` přímo ve screenu – logika patří spíše do dedikovaného repozitáře.
- ⚠️ **`admin_reservation_forms.dart`:** async načítání služeb přes Supabase uvnitř Stateful widgetu (`_loadServicesState`).
- ⚠️ **`premium_upsell_dialog.dart`:** aktivace modulu, Supabase update/insert v dialogu.

### 4.2 Globální vs. lokální stav

- ✅ **Použití `FutureProvider` / `StreamProvider` / `StateNotifier`:** standardní Riverpod vzorce v `lib/features/admin/providers/`.
- ⚠️ **Velké notifiery:** `admin_tasks_provider.dart`, `finance_billing_provider.dart`, `settlements_provider.dart` – monolitické soubory s vysokou cyklomatickou složitostí (údržba, testovatelnost).

### 4.3 České komentáře (POVINNÉ PROČ)

- ✅ **Část souborů má detailní české dokumentační komentáře** (např. `admin_tasks_repository.dart`, `zones_provider.dart`, `automation_queue_repository.dart`, `module_icon_mapper.dart`, `finance_repository.dart`, části `admin_reservation_forms.dart`).
- ⚠️ **Ne všechny třídy/funkce v `lib/features/admin/providers/` mají na úrovni souboru nebo u každé veřejné metody komentář „PROČ“** – např. čisté datové třídy (`ReservationRow`, `BillingGroup`) mají často jen krátké popisy; některé repozitáře začínají rovnou `class X` bez úvodního bloku.

### 4.4 Ostatní

- ⚠️ **`lib/features/admin/providers/task_assignment_engine.dart`:** uzamčené jádro business logiky (pravidlo projektu: neupravovat). Audit pouze konstatuje existenci – refaktorování do menších částí bez změny chování nebylo posuzováno.

---

## 5. ADDITIVE DEVELOPMENT (SQL migrace)

Destruktivní operace nalezené v `supabase/migrations/*.sql`:

| Soubor | Operace |
|--------|---------|
| `20250306_unified_profiles_ghost_strategy.sql` | `DROP TABLE user_roles`, `DROP TABLE profiles` (s CASCADE), `TRUNCATE` na více tabulkách – **historická přestavba schématu**, masivní ztráta dat při reaplikaci na neprázdné DB. |
| `20250301_currencies_and_modules_price_eur.sql` | `ALTER TABLE modules DROP COLUMN currency` |
| `20260322170000_remove_keybox_code.sql` | `DROP COLUMN keybox_code` |
| `20260322180000_channels_refactoring_templates.sql` | `DROP COLUMN body`, `DROP COLUMN language_code` na šablonách – **schválená výjimka / kanálový refaktor** (viz komentář v migraci). |

- ⚠️ **Keybox / currency / template sloupce:** destruktivní vůči starým sloupcům; pro **nové nasazení ze zálohy** bez těchto migrací v pořadí = riziko.
- ✅ **Žádný další `DROP TABLE` v novějších samostatných migracích** mimo výše uvedené (grep v aktuálním stavu).

---

## Shrnutí priorit

1. ❌→⚠️ **Sjednotit zápis do `profiles` přes `safeFrom` nebo RPC** a eliminovat `client.from('profiles')` bez tenant scope v admin týmu.  
2. ⚠️ **Nahradit ruční `.eq('tenant_id')` za `safeFrom`** v dlouhých providerech (`finance_billing_provider`, `reports_provider`) kvůli konzistenci se super-admin impersonací.  
3. ⚠️ **Admin offline-first:** explicitní architektonické rozhodnutí zdokumentovat (online-first web admin vs. Drift pro field worker).  
4. ⚠️ **i18n:** doplnit klíče pro `—`, rok, `HH:mm` hint, chybové snackbary se `$e`.  
5. ⚠️ **Přesun DB logiky z obřích screenů/dialogů do repozitářů.**

*Konec auditu – žádná automatická verifikace buildu ani spuštění testů nebyla provedena.*
