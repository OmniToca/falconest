# MVP Readiness Report – Falconest

**Datum analýzy:** 1. března 2025  
**Kontext:** Falconest je field-service a operations aplikace pro malé property managery (10–20 jednotek/vil ve Španělsku). Jádro hodnoty: nahrazení WhatsApp a Excelu pro přiřazování úkolů (úklid, check-in, údržba) a automatizace přípravy měsíčního vyúčtování pro účetního (gestoría).

---

## 1. CURRENT STATE (Co máme hotové)

### 1.1 Autentizace a bezpečnost
| Položka | Stav | Detail |
|---------|------|--------|
| Přihlášení e‑mail/heslo | ✅ Hotovo | `login_screen.dart`, Supabase Auth |
| PIN pro rychlé odemčení (mobil) | ✅ Hotovo | `pin_setup_screen`, `pin_verify_screen`, `pin_storage.dart` (flutter_secure_storage) |
| Role a routing | ✅ Hotovo | `auth_notifier.dart` – role: admin, manager, worker, cleaner, driver, maintenance, property_owner, super_admin |
| Profil a tenant kontext | ✅ Hotovo | `profiles`, `tenant_id`, `tenantIdForData` |
| Pozvánky a nastavení hesla | ✅ Hotovo | `invite_screen.dart`, `set_password_screen.dart` |
| Waiting room | ✅ Hotovo | Čekání na aktivaci účtu |
| Kill switch / platby | ✅ Hotovo | `payment_required_screen`, `suspended` |

### 1.2 Databáze a backend
| Položka | Stav | Detail |
|---------|------|--------|
| Migrace Supabase | ✅ Hotovo | ~87 migrací, RLS politiky |
| Klíčové tabulky | ✅ Hotovo | zones, clients, apartments, reservations, tasks, apartment_services, reservation_services, employee_cash_wallets, employee_cash_transactions, billing_snapshots, apartment_ical_sources, user_devices |
| Edge Functions | ✅ Hotovo | `ical-fetch`, `daily-task-summary`, `template-reminders`, `create-checkout` |
| Supabase Storage | ✅ Hotovo | Bucket `falconest_media` pro fotky úkolů, účtenky |

### 1.3 Manager Web / Admin Dashboard
| Položka | Stav | Detail |
|---------|------|--------|
| Layout a navigace | ✅ Hotovo | `AdminLayout`, sidebar s 10 položkami |
| Nástěnka | ✅ Hotovo | `AdminDashboardScreen` |
| Personál / Tým | ✅ Hotovo | `AdminTeamScreen` – CRUD zaměstnanců, role, zóny |
| Byty | ✅ Hotovo | `AdminApartmentsScreen` – CRUD apartmánů, služby, majitelé |
| Rezervace | ✅ Hotovo | `AdminReservationsScreen` – Kanban, CRUD, změna statusu |
| Úkoly | ✅ Hotovo | `AdminTasksScreen` – plachta, přiřazení, ruční úpravy |
| Planning Calendar | ✅ Hotovo | `PlanningCalendarScreen` – timeline rezervací a úkolů |
| Zaměstnanecká pokladna | ✅ Hotovo | `FinanceDashboardScreen` – dluhy, potvrzení odevzdání |
| Reporty | ✅ Hotovo | `ReportsScreen` – analytika |
| Klienti | ✅ Hotovo | `AdminClientsScreen` – CRM |
| Komunikační šablony | ✅ Hotovo | `CommunicationTemplatesScreen` |
| Import rezervací z Excelu | ✅ Hotovo | `ReservationImportService` – šablona + import |
| iCal Sync | ✅ Hotovo | `IcalSyncService`, záložka v detailu apartmánu, Edge Function `ical-fetch` |
| Generování úkolů z rezervací | ✅ Hotovo | `generateSmartTasks()` v `AdminTasksProvider`, tlačítko na plachtě úkolů |
| Billing (uzamčení měsíce, PDF, Excel) | ✅ Hotovo | `BillingActionService`, `BillingPdfService`, `BillingExportService` |
| Moduly a upsell | ✅ Hotovo | `finance_export` jako placený sub-modul, `PremiumUpsellDialog` |

### 1.4 Field Worker Mobile UI
| Položka | Stav | Detail |
|---------|------|--------|
| Dashboard „Moje práce“ | ✅ Hotovo | `WorkerDashboardScreen` – Dnes/Zítra/Později |
| Pull-to-refresh | ✅ Hotovo | Sync ze Supabase |
| Karty úkolů | ✅ Hotovo | `_TaskCard` – název, adresa, typ, čas, status |
| Otevření detailu úkolu | ✅ Hotovo | `context.push('/worker/task/${task.id}')` |
| Tlačítko Začít | ✅ Hotovo | `TaskCompleteWithPhotoSection` – potvrzovací dialog, `updateStatus('in_progress')` |
| Tlačítko Dokončit | ✅ Hotovo | S podporou `requires_photo` – blokace bez fotek |
| Nahrání fotek k úkolu | ✅ Hotovo | `TaskPhotoUploader`, `MediaService` → Supabase Storage |
| Hlášení závad | ✅ Hotovo | `IssueReporterDialog` – vytvoření task typu `issue`, fotky |
| Firemní výdaje (účtenka) | ✅ Hotovo | `AddCompanyExpenseDialog` – fotka účtenky, částka, apartmán |
| Výběr hotovosti | ✅ Hotovo | `CashCollectionDialog` při check-in/transfer |
| Absence | ✅ Hotovo | `WorkerAbsencesScreen` |
| Zaměstnanecká pokladna | ✅ Hotovo | `WorkerWalletScreen` |
| Offline-first | ✅ Hotovo | Drift SQLite, `MutationQueueService`, offline procesory pro fotky, závady, výdaje |

### 1.5 Owner portál
| Položka | Stav | Detail |
|---------|------|--------|
| Majitel dashboard | ✅ Hotovo | Apartmány, rezervace, kalendář |
| Billing (podklady) | ✅ Hotovo | `OwnerBillingScreen` – PDF export |

### 1.6 Multi-tenant a i18n
| Položka | Stav | Detail |
|---------|------|--------|
| Tenant izolace | ✅ Hotovo | `tenant_id` v tabulkách, RLS, `tenantIdForData` |
| Lokalizace | ✅ Hotovo | easy_localization, cs.json, en.json, es.json |
| Měna tenanta | ✅ Hotovo | `currencies`, `tenant_currency_provider` |

---

## 2. MVP GAP ANALYSIS (Co chybí pro první verzi)

### 2.1 Manager Web: Import iCal a automatické generování úkolů

**Stav:** Částečně hotovo, chybí jeden propojovací krok.

| Aspekt | Stav | Detail |
|--------|------|--------|
| iCal Sync | ✅ Hotovo | Rezervace se ukládají do DB se `status: 'new'` a `external_uid`. UI v záložce apartmánu. |
| Automatické generování úkolů | ⚠️ Rozpojeno | `generateSmartTasks()` bere **pouze** rezervace se `status: 'confirmed'`. Rezervace z iCal mají `status: 'new'`. |
| Chybějící krok | ❌ Gap | Dispečer musí: 1) spustit iCal sync, 2) ručně změnit status rezervací na `confirmed`, 3) ručně kliknout na „Generovat úkoly“ na plachtě úkolů. Žádný jeden „magic“ flow. |
| Doporučení | | Možnost A: Po iCal syncu nabídnout batch „Potvrdit a vygenerovat úkoly“. Možnost B: Dokumentovat 3-krokový flow a považovat ho za MVP. |

### 2.2 Manager Web: „End-of-month magic button“

**Stav:** Funkčně hotovo, UX závisí na modulu.

| Aspekt | Stav | Detail |
|--------|------|--------|
| Billing snapshot | ✅ Hotovo | `billing_snapshots` – uzamčení měsíce, JSONB snapshot_data |
| PDF export per klient | ✅ Hotovo | `BillingPdfService.generateAndDownloadPdf()` |
| Excel export | ✅ Hotovo | `BillingExportService.exportAllToExcel()`, `exportClientToExcel()` |
| UI „Podklady pro fakturaci“ | ✅ Hotovo | `FinanceBillingDialog` – výběr měsíce, seskupení dle klientů |
| Modul `finance_export` | ⚠️ Placený | Tlačítko „Podklady pro fakturaci“ zobrazuje `PremiumUpsellDialog`, pokud modul není aktivní. |
| Doporučení | | Pro první klienty aktivovat `finance_export` v rámci základní licence nebo trial. Pro MVP je funkce připravená. |

### 2.3 Field Worker Mobile: Denní úkoly + Start/Finish

**Stav:** Hotovo.

| Aspekt | Stav | Detail |
|--------|------|--------|
| Denní přehled | ✅ Hotovo | Seskipení Dnes/Zítra/Později |
| Kliknutí na úkol | ✅ Hotovo | Navigace na `/worker/task/:id` |
| Tlačítko Začít | ✅ Hotovo | `worker.task_detail_start_work` |
| Tlačítko Dokončit | ✅ Hotovo | `widget.finishKey` (např. `worker.task_detail_finish`) |
| Potvrzovací dialogy | ✅ Hotovo | Před startem i před dokončením |
| Offline | ✅ Hotovo | Drift, mutation queue, sync při návratu online |

**Gap:** Žádný významný. UX je jednoduché a odpovídá specifikaci.

### 2.4 Field Worker Mobile: Kamera (fotky důkazů, závady)

**Stav:** Hotovo.

| Aspekt | Stav | Detail |
|--------|------|--------|
| Fotky při dokončení úkolu | ✅ Hotovo | `TaskPhotoUploader` – max 3 fotky, `ImageSource.camera` (mobil) |
| `requires_photo` | ✅ Hotovo | Dokončení zablokováno bez fotek |
| Upload do Storage | ✅ Hotovo | `MediaService` → `falconest_media/{tenant}/tasks/` |
| Offline fotky | ✅ Hotovo | `offline_photo_task_processor` – fronta, upload po syncu |
| Hlášení závad | ✅ Hotovo | `IssueReporterDialog` – typ `issue`, fotky |
| Web | ⚠️ Omezení | Na webu `kIsWeb` blokuje kameru; worker flow je primárně mobilní. |

**Gap:** Pro typický mobilní worker scénář je vše připraveno.

### 2.5 Field Worker Mobile: Evidence výdajů (účtenka + částka)

**Stav:** Hotovo.

| Aspekt | Stav | Detail |
|--------|------|--------|
| Dialog firemního výdaje | ✅ Hotovo | `AddCompanyExpenseDialog` |
| Fotka účtenky | ✅ Hotovo | `MediaService.pickAndCompressImage(source: ImageSource.camera)` |
| Zadání částky | ✅ Hotovo | `_amountController` |
| Volitelný apartmán | ✅ Hotovo | Pro přiřazení nákladů k bytu |
| Uložení | ✅ Hotovo | `CashWalletRepository` → `employee_cash_transactions` |
| Pohled admina | ✅ Hotovo | Finance dashboard, sekce „Náklady k proplacení“ |
| Offline | ⚠️ Částečně | Zápis výdaje má offline podporu (mutation queue). Fotka účtenky vyžaduje online upload – při offline se zobrazí upozornění a nelze pokračovat. |

**Gap:** Pro online scénář je MVP splněno. Offline s fotkou účtenky není podporováno.

---

## 3. TECHNICAL DEBT & BLOCKERS

### 3.1 Kritické rizika pro demo

| Riziko | Závažnost | Popis |
|--------|-----------|-------|
| Modul finance_export | Střední | Bez aktivovaného modulu admin nevidí „Podklady pro fakturaci“. Řešení: aktivovat modul pro demo tenanta. |
| iCal → úkoly flow | Střední | Bez dokumentace 3 kroků (sync → potvrzení → generování) bude působit neintuitivně. |
| Offline účtenka | Nízká | Při offline nelze uložit firemní výdaj s fotkou. Pro většinu demo stačí online. |

### 3.2 Mock data a neúplné propojení

| Položka | Umístění | Popis |
|---------|----------|--------|
| Mock faktury (nastavení) | `client_billing_tab.dart` cca ř. 791 | `mockItems` – 2–3 statické položky pro „Moje faktury“. |
| Mock faktury (Super Admin) | `tenant_detail_screen.dart` cca ř. 1062, 1087 | `_buildMockInvoicesList` – 3 mock faktury. |
| Poznámka | | Tyto mocky nejsou v hlavním provozním flow (billing, worker). Pro demo je vhodné je skrýt nebo nahradit reálnými daty. |

### 3.3 Error handling a stabilita

| Oblast | Stav |
|--------|------|
| Admin | Četné `try/catch` s `debugPrint` nebo SnackBar; chybí jednotný error reporting. |
| Worker | Podpora offline banneru a sync errorů; místy základní ošetření. |
| Auth | Offline fallback přes `ProfileCacheService`. |
| iCal | `IcalSyncResult.error` vrací chybovou zprávu do UI. |

**Doporučení:** Pro demo zvolit předem otestované scénáře; neočekávané chyby mohou být hůř vidět.

### 3.4 Zamčený kód

| Soubor | Důvod |
|--------|--------|
| `task_assignment_engine.dart` | CRITICAL RULE – žádné změny. Logika generování úkolů je chráněná. |

### 3.5 Závislosti na platformě

| Položka | Omezení |
|---------|---------|
| Kamera | `kIsWeb` – na webu není k dispozici. Worker flow je určen pro mobil. |
| PIN | Mobil only; web nemá PIN flow. |
| Drift / offline | Mobil: plný offline. Web: přímé volání Supabase, bez lokální DB. |

---

## 4. SHRNUTÍ A DOPORUČENÍ

### Co je pro MVP připravené
- Autentizace, role, tenant izolace
- Kompletní admin dashboard (CRM, rezervace, úkoly, finance, iCal)
- Mobilní worker UI (úkoly, Start/Finish, fotky, závady, výdaje)
- Billing (uzamčení měsíce, PDF, Excel) – vyžaduje modul finance_export
- Import z Excelu, iCal sync

### Co doplnit / upravit pro první vydání
1. **iCal flow:** Zvážit batch „Potvrdit a vygenerovat úkoly“ nebo jasnou dokumentaci 3 kroků.
2. **finance_export:** Pro první klienty aktivovat v rámci trial/základní licence.
3. **Mock faktury:** Skrýt nebo připojit na reálná data před demo.

### Odhad připravenosti na první klienta
**~90 %** – Základní flow jsou implementované a propojené. Zbývá především UX a obchodní rozhodnutí kolem modulu finance_export a iCal workflow.
