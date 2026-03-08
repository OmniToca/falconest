# FalcoNest – Celkový audit projektu (stav k 28. 2. 2025)

> **Pouze analýza.** Report vychází z reálné skenace codebase (Dart, Isar, routování, DB schéma).

---

## 1. PLNĚ IMPLEMENTOVÁNO (Hotové UI + Logika + DB)

### Autentizace a onboarding

| Funkce | Soubory | Poznámka |
|--------|---------|----------|
| Login | `login_screen.dart`, `auth_notifier.dart` | Přihlášení přes Supabase Auth |
| Registrace nové agentury | `onboarding_screen.dart` | Formulář: název agentury, jméno, email, heslo. RPC `register_agency` pro organické; pozvánka → signUp + propojení profilu |
| Zvací flow (invite) | `invite_screen.dart`, `set_password_screen.dart` | Token v URL, nastavení hesla, propojení s `invitations` |
| Čekárna (waiting-room) | `waiting_room_screen.dart` | Pro uživatele bez `tenant_id` |
| Kill-Switch / platnost | `auth_notifier.dart`, `app_router.dart` | `paid_until` blokuje přístup na `/payment-required` |
| PIN (mobilní) | `pin_setup_screen.dart`, `pin_verify_screen.dart` | Setup, verify, change flow |
| Impersonace (Super Admin) | `auth_notifier.dart`, `admin_layout.dart` | Převtělení na tenanta, banner v UI |

### Admin – hlavní moduly

| Modul | Obrazovka | Provider / logika | DB tabulky |
|-------|-----------|-------------------|------------|
| **Nástěnka** | `AdminDashboardScreen` | `adminTasksStreamProvider`, `adminReservationsProvider`, `apartmentsProvider`, `adminTeamProvider` | tasks, reservations, apartments, profiles |
| **Personál** | `AdminTeamScreen` | `AdminTeamProvider`, `AdminTeamNotifier` | profiles, invitations, staff_absences |
| **Byty** | `AdminApartmentsScreen` | `apartmentsProvider`, `zonesProvider`, `apartmentOwnersProvider` | apartments, zones, apartment_owners |
| **Rezervace** | `AdminReservationsScreen` | `adminReservationsProvider`, `adminReservationsRepository` | reservations, apartment_services, reservation_services |
| **Úkoly** | `AdminTasksScreen` | `adminTasksStreamProvider`, `AdminTasksNotifier` | tasks, task_categories |
| **Plánovací kalendář** | `PlanningCalendarScreen` | `planningCalendarProvider` | tasks, reservations |
| **Finance (pokladna)** | `FinanceDashboardScreen` | `financeCashProvider`, `employeeCashWalletsProvider` | employee_cash_wallets, employee_cash_transactions |
| **Reporty** | `ReportsScreen` | `reportsDataProvider`, `ReportsProvider` | tasks, apartment_services, reservation_services |
| **Klienti (CRM)** | `AdminClientsScreen` | `clientsProvider` | clients |
| **Komunikace (šablony)** | `CommunicationTemplatesScreen` | `messageTemplatesAdminProvider` | tenant_message_templates |

### Generátor úkolů a přiřazení personálu

| Funkce | Implementace | Soubory |
|--------|-------------|---------|
| **Generovat návrhy** | Plně funkční – volá `generateSmartTasks()` + `generateScheduledTasks()` | `admin_tasks_screen.dart` → `admin_tasks_provider.dart` |
| **TaskAssignmentEngine** | Reálný engine – `pickAssigneeWithCollisionAvoidance`, load balancing, zónové preference, kontrola kolizí | `task_assignment_engine.dart` |
| **Trigger typy** | before_checkin, after_checkout, both_ways, on_demand, scheduled | `admin_tasks_provider.dart`, `reservation_services_repository.dart` |
| **Přepočítat personál** | `recalculateAssignees()` – znovu volá engine pro vybrané úkoly | `admin_tasks_provider.dart` |

### Rezervace – zámek (Read-Only)

| Stav | Logika | Soubor |
|------|--------|--------|
| `checked_out`, `cancelled` | `isReadOnly = true` – banner, blokované vstupy, skryté uložit | `admin_reservation_forms.dart` (EditReservationDialog) |

### Zaměstnanecká pokladna (dýšky)

| Vrstva | Implementace |
|--------|--------------|
| Admin | `FinanceDashboardScreen` – přehled dluhů, potvrzení převzetí hotovosti, řešení failed cash alerts |
| Worker | `WorkerWalletScreen` – zůstatek, historie, firemní výdaje (`AddCompanyExpenseDialog`) |
| Check-in / Transfer | `CashCollectionDialog` – výběr od hosta, metadata.amount_to_collect |

### Klientský portál (majitelé)

| Obrazovka | Popis |
|-----------|-------|
| `OwnerApartmentsScreen` | Seznam apartmánů majitele |
| `OwnerReservationsScreen` | Rezervace k apartmánům |
| `OwnerTasksScreen` | Read-only Kanban (Zadáno / Probíhá / Hotovo) |
| `OwnerPlanningCalendarScreen` | Kalendář rezervací |
| `OwnerApartmentDetailScreen` | Detail apartmánu (route `/owner/apartments/:id`) |

### Worker (personál)

| Obrazovka | Popis |
|-----------|-------|
| `WorkerDashboardScreen` | Dnešní úkoly, přepínání stavu |
| `WorkerAbsencesScreen` | Evidence absencí (`AddAbsenceDialog`) |
| `WorkerWalletScreen` | Peněženka (viz výše) |
| `WorkerTaskDetailScreen` | Detail úkolu (typ: cleaning, transfer, check-in, maintenance, issue) |

### Offline-first a Isar

| Isar model | Účel |
|------------|------|
| `TaskLocal` | Lokální úkoly |
| `ReservationLocal` | Lokální rezervace |
| `ApartmentLocal` | Lokální byty |
| `ClientLocal` | Lokální klienti |
| `TenantLocal` | Lokální tenant |
| `MessageTemplateLocal` | Šablony zpráv |
| `PendingMutationLocal` | Fronta změn k odeslání |
| `PendingAuditAction` | Audit akce |

Web nemá Isar – `kIsWeb` → Supabase-only.

### Super Admin

| Funkce | Implementace |
|--------|--------------|
| Dashboard | `SuperAdminDashboard` – MRR, přehled tenantů |
| Detail tenanta | `TenantDetailScreen` |
| Onboarding Wizard | `SuperAdminOnboardingWizardScreen` – import z Master Excelu (personál, služby, apartmány) |
| Audit log | `AuditLogScreen` – záznamy z `audit_logs` |
| Moduly a billing | `module_provider`, `ClientBillingTab`, Stripe integrace (částečně) |

### Edge Functions

| Funkce | Účel |
|--------|------|
| `daily-task-summary` | Cron ráno – FCM notifikace s počtem dnešních úkolů na zaměstnance |
| `template-reminders` | Cron 7/11/15/19 (Madrid) – FCM připomenutí šablon pro transfery (48h, 24h, 1h) |
| `create-checkout` | Stripe checkout (existuje) |

### Push notifikace

| Vrstva | Stav |
|--------|------|
| FCM tokeny | `PushNotificationService` + `UserDeviceRepository` – zápis do `user_devices` po přihlášení |
| In-app zvoneček | `_NotificationsBell` v admin layout – Realtime stream z `notifications` |

---

## 2. ČÁSTEČNĚ IMPLEMENTOVÁNO / ROZPRACOVÁNO

### Generátor úkolů – strhávání kreditů

| Co je | Stav |
|-------|------|
| DB | `tenant_wallets`, `wallet_transactions`, RPC `deduct_wallet_credits()` – existuje |
| UI | `WalletIndicator`, `WalletTopUpDialog` – zobrazení balance, katalog balíčků |
| Integrace | **Chybí:** `generateSmartTasks()` NESTRHÁVÁ kredity – nikde se nevolá `deduct_wallet_credits`. Generátor běží bez omezení. |

### Top-Up peněženky (nákup kreditů)

| Co je | Stav |
|-------|------|
| Dialog | `WalletTopUpDialog` – balíčky (500/5€, 5000/40€, 15000/100€) |
| Stripe | Komentář v kódu: *„Stripe integrace bude doplněna v dalším kroku.“* – tlačítko `_onBuy` jen zobrazuje toast. |

### Tlačítko „Generovat návrhy“

| Stav | Detaily |
|------|---------|
| **UI** | `_GenerateButton` – aktivní při `automaticTasksActive` (modul `automatic_tasks`), jinak zamčené s PremiumUpsellDialog |
| **Logika** | Volá `generateSmartTasks()` + `generateScheduledTasks()` – **reálný generátor** s TaskAssignmentEngine |
| **Kredity** | Nestrhává kredity – bez volání `deduct_wallet_credits` |

### Modul finance_export (Podklady pro fakturaci)

| Co je | Stav |
|-------|------|
| Obrazovka | `FinanceBillingScreen` – měsíční přehled dokončených úkolů, export PDF |
| Modul | Sub-modul `finance_export` – při neaktivním zobrazen jako zamčený s upsell |
| Logika | `PdfBillingService` – generuje PDF, `finance_repository` – označení `invoiced_at` |

### Preference notifikací

| Co je | Stav |
|-------|------|
| Tabulka | `notification_preferences` – `daily_summary_enabled`, `upcoming_task_enabled`, `new_task_assigned_enabled` |
| Model | `NotificationPreferencesModel` existuje |
| Edge funkce | `daily-task-summary` čte `daily_summary_enabled` |
| **UI** | **Chybí** – v Nastavení není záložka pro úpravu preferencí notifikací |

### Řešení konfliktů hotovosti

| Co je | Stav |
|-------|------|
| Sekce | `_FailedCashAlertsSection` v `FinanceDashboardScreen` – zobrazuje úkoly, kde pracovník nepotvrdil výběr |
| Řešení | `resolveFailedCashCollection()` – admin potvrdí převzetí |

### Zámek hotových úkolů v admin UI

| Co je | Stav |
|-------|------|
| Rezervace | Plně uzamčeno (checked_out, cancelled) |
| Úkoly | **Chybí** – v admin task edit/detail není zámek pro `status = completed` nebo `invoiced_at != null`. Úkoly ve stavu Hotovo/Vyfakturovaný se skrývají z aktivních pohledů, ale pokud by byl záznam otevřen, editace není explicitně blokována. |

### Platební brána (Stripe)

| Co je | Stav |
|-------|------|
| Routy | `/payment-success`, `/payment-cancel` – zakomentované v `app_router.dart` |
| `create-checkout` | Edge funkce existuje |
| Webhook / doplnění kreditů | V DB schématu popsáno – Super Admin / Stripe webhook; v kódu neověřeno |

### Šablony zpráv – odesílání

| Co je | Stav |
|-------|------|
| CRUD šablon | Plně – `CommunicationTemplatesScreen`, `template_editor_dialog`, `TemplatePlaceholderService` |
| Edge `template-reminders` | Odesílá FCM s textem šablony (placeholdery vyplněny) |
| **Odeslání z UI** | **Neověřeno** – možná chybí tlačítko „Odeslat hostovi“ přímo v admin/detail úkolu? |

---

## 3. CHYBÍ / POUZE V PLÁNU

### Moduly bez obrazovky (ModuleIconMapper)

| Modul | `tabIndex` | Stav |
|-------|------------|------|
| `warehouse` | null | Placeholder – „coming soon“ |
| `smart_lock` | null | Placeholder |
| `automation` | null | Placeholder |
| `automatic_tasks` | null | Feature flag – nemá vlastní obrazovku, odemyká tlačítko „Generovat návrhy“ na Úkolech |
| `finance_export` | null | Sub-modul – přístup přes Finance dashboard (tlačítko Fakturace) |

### Tabulky v DB bez odpovídající UI

| Tabulka | Popis | Stav v UI |
|---------|-------|-----------|
| `invoices` | Stripe faktury | Používáno v `ClientBillingTab`, `billing_overview_provider` – částečně |
| `app_super_admins` | Super admin účty | Jen v backendu |
| `invitations.roles`, `invitations.weekly_hours`, `start_date`, `end_date` | Rozšířená pozvánka | Částečně – záleží na flow |

### Ostatní

| Položka | Popis |
|---------|-------|
| **Notification preferences UI** | Uživatel nemůže v Nastavení zapnout/vypnout ranní souhrn, upozornění před úkolem atd. |
| **Storage falconest_media** | Bucket existuje v dokumentaci, struktura `tenant_id/modul/soubor.jpg` – použití pro účtenky (firemní výdaje), fotky úkolů |
| **reference_number** | Generováno v DB pro tasks/reservations – zobrazení v UI závisí na konkrétních komponentách |

---

## Shrnutí – klíčové zjištění

1. **Generátor úkolů:** Plně funkční – TaskAssignmentEngine, load balancing, kolize, svaté vs. flexibilní úkoly. Tlačítko „Generovat návrhy“ NENÍ slepé.
2. **Stržení kreditů:** Tabulky a RPC existují, ale Flutter **nikdy nevolá** `deduct_wallet_credits` – generátor běží bez omezení.
3. **Top-Up:** UI existuje, Stripe checkout chybí – jen toast.
4. **Rezervace – zámek:** Implementováno pro `checked_out` a `cancelled`.
5. **Preference notifikací:** Tabulka + model + edge funkce, **chybí UI** pro uživatele.
6. **Moduly warehouse, smart_lock, automation:** Placeholder v menu, bez funkcí.
