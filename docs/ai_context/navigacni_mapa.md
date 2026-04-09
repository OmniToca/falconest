# Navigační mapa aplikace (vizuální a navigační audit)

Datum auditu: 2026-04-09  
Zdroj pravdy: `lib/core/router/app_router.dart`, `lib/features/admin/admin_layout.dart`, `lib/features/owner/owner_layout.dart`, `lib/features/worker/screens/worker_dashboard_screen.dart`

## Důležité principy navigace

- **Admin** používá `IndexedStack` v `AdminLayout` (záložky podle indexu), ne samostatné route pro každou admin obrazovku.
- **Owner** používá `IndexedStack` v `OwnerLayout` (6 záložek), ne samostatné route pro každou owner obrazovku.
- **Worker** používá hlavní route `/worker` + pod-routy (`/worker/wallet`, `/worker/earnings`, `/worker/absences`, `/worker/mutation-queue`).

---

## Admin (sidebar/menu)

### Globální topbar akce

- Hamburger: otevření/skrytí sidebaru.
- Ikona kalendáře: přepnutí na `PlanningCalendarScreen`.
- Zvoneček notifikací: dropdown + přesměrování na task detail / taby (Tasks, Team, Finance).
- Profilové menu: `Switch to mobile`, `Settings`, `Logout` nebo `Back to command center`.

### Záložky (IndexedStack)

1. **Nástěnka**  
   Screen: `lib/features/admin/admin_dashboard_screen.dart`  
   Hlavní akce:
   - Quick actions (např. přidat úkol, generovat návrhy).
   - Klikatelné KPI/panely s cross-navigation do jiných tabů (Tasks, Finance, Team, Clients, Automations).

2. **Personál**  
   Screen: `lib/features/admin/admin_team_screen.dart`  
   Hlavní akce:
   - Přidání/editace člena týmu (dialogy).
   - Vyhledávání, taby, filtry.
   - Akce nad řádky (edit/delete), retry/confirm akce.

3. **Apartmány**  
   Screen: `lib/features/admin/admin_apartments_screen.dart`  
   Hlavní akce:
   - Vyhledávání + přidání apartmánu.
   - Taby sekcí, CRUD dialogy.
   - iCal správa (zdroje, tokeny, import), formuláře (dropdown/switch).

4. **Rezervace**  
   Screen: `lib/features/admin/admin_reservations_screen.dart`  
   Hlavní akce:
   - Přidat rezervaci.
   - Import/export včetně `.xlsx` šablony.
   - Timeline/List (Kanban), měsícová navigace.
   - Edit/smazání rezervace, WhatsApp akce, drag&drop status.

5. **Úkoly**  
   Screen: `lib/features/admin/admin_tasks_screen.dart`  
   Hlavní akce:
   - Přidat/editovat úkol.
   - Vyhledávání, filtry, checklisty.
   - Formulářové akce (typ, assignee, stav), řádkové akce + potvrzení.

6. **Plánovací kalendář**  
   Screen: `lib/features/calendar/screens/planning_calendar_screen.dart`  
   Hlavní akce:
   - Týdenní navigace (prev/next/today).
   - Filtr pracovníka.
   - Klik na task blok (otevření editace), legenda, timeline mřížka.

7. **Mapa / Dispatch**  
   Screen: `lib/features/admin/screens/admin_map_dispatch_screen.dart`  
   Hlavní akce:
   - Filtr podle pracovníka.
   - Mapové markery, trasy (polyline), legenda.
   - Otevření externí mapové atribuce.

8. **Finance**  
   Screen: `lib/features/admin/finance_dashboard_screen.dart`  
   Hlavní akce:
   - Taby: Peněženky / Vyúčtování / Podklady pro fakturaci.
   - Detail wallet (modal), převzetí hotovosti.
   - Alerty + resolve akce, unlock trial u zamčených částí.

9. **Reporty**  
   Screen: `lib/features/admin/screens/reports_screen.dart`  
   Hlavní akce:
   - Month picker.
   - KPI a grafy, výkonové přehledy (read-only).

10. **Klienti**  
    Screen: `lib/features/admin/screens/admin_clients_screen.dart`  
    Hlavní akce:
    - Vyhledávání (debounce), přidání klienta.
    - Taby segmentů, rychlé filtry.
    - Detail klienta, mazání s potvrzením, načítání dalších položek.

11. **Komunikace (šablony)**  
    Screen: `lib/features/communication/screens/communication_templates_screen.dart`  
    Hlavní akce:
    - Přidat/editovat/smazat šablonu.
    - Seznam trigger/channel typů.

12. **Automatizace**  
    Screen: `lib/features/admin/admin_automations_screen.dart`  
    Hlavní akce:
    - Taby: Rules / Queue / Log.
    - Add/edit/delete rule, aktivace/deaktivace.
    - Queue operace (`send now`, `cancel`, edit payload), seed default rules.

### Poznámka k modulům bez obrazovky

Sidebar je modulový podle DB klíčů (`ModuleIconMapper`). Některé moduly mohou mít `tabIndex = null` (zatím bez vlastní obrazovky) a zobrazí se jako zamčené/coming soon.

---

## Worker (drawer menu)

Zdroj menu: `lib/features/worker/screens/worker_dashboard_screen.dart`

1. **Moje práce (Dashboard)**  
   Screen: `lib/features/worker/screens/worker_dashboard_screen.dart`  
   Hlavní akce:
   - Pull-to-refresh + synchronizace.
   - Karty úkolů (tap -> detail úkolu).
   - Otevření navigace do map.
   - Sync bannery a warning banner vysoké hotovosti (CTA do Peněženky).

2. **Peněženka**  
   Screen: `lib/features/worker/screens/worker_wallet_screen.dart`  
   Hlavní akce:
   - Přehled zůstatku.
   - Tlačítko „Přidat firemní výdaj“.
   - Historie transakcí + náhled účtenky.

3. **Moje výdělky**  
   Screen: `lib/features/worker/screens/worker_earnings_screen.dart`  
   Hlavní akce:
   - Summary karty (pending/paid).
   - Seznam výdělků se statusy (read-only).

4. **Moje nepřítomnost**  
   Screen: `lib/features/worker/screens/worker_absences_screen.dart`  
   Hlavní akce:
   - FAB „Přidat nepřítomnost“.
   - Segmentové filtry (all / approved / pending+rejected).
   - Refresh seznamu.

### Další viditelné akce ve Worker draweru

- Přepnutí jazyka (cs/en/es).
- Přepnutí na desktop režim (jen admin/manager).
- Změna PIN (pokud je PIN aktivní a nejde o web).
- Logout.

### Skrytá/support stránka mimo hlavní menu

- `WorkerMutationQueueScreen` (`/worker/mutation-queue`) je v routeru, ale není jako standardní položka v draweru; otevírá se ze sync banneru (`worker_dashboard_sync_banners.dart`).

---

## Owner (sidebar/menu)

Zdroj: `lib/features/owner/owner_layout.dart` (`IndexedStack`, 6 záložek)

1. **Nástěnka**  
   Screen: `lib/features/owner/owner_dashboard_screen.dart`  
   Hlavní akce:
   - Metriky (upcoming stays, uninvoiced services).
   - CTA „Nahlásit závadu“.

2. **Apartmány**  
   Screen: `lib/features/owner/owner_apartments_screen.dart`  
   Hlavní akce:
   - Grid karet apartmánů.
   - Otevření detailu apartmánu.
   - FAB „Nahlásit závadu“.

3. **Rezervace**  
   Screen: `lib/features/owner/owner_reservations_screen.dart`  
   Hlavní akce:
   - Vytvoření rezervace/owner stay.
   - Editace dle statusu, mazání s potvrzením.
   - Kanban pohled podle statusů.

4. **Úkoly**  
   Screen: `lib/features/owner/owner_tasks_screen.dart`  
   Hlavní akce:
   - Read-only Kanban.
   - Detail úkolu v dialogu.
   - FAB „Nahlásit závadu“.

5. **Kalendář**  
   Screen: `lib/features/owner/owner_planning_calendar_screen.dart`  
   Hlavní akce:
   - Týdenní navigace.
   - Filtr podle apartmánu.
   - Klik na task blok (read-only detail).

6. **Billing**  
   Screen: `lib/features/owner/owner_billing_screen.dart`  
   Hlavní akce:
   - Seznam billing snapshotů.
   - Stažení PDF.
   - Potvrzení nákladů (approve/confirm flow).

### Spodní akce

- Logout (`_LogoutTile`) v sidebaru.

---

## Route existuje, ale není hlavní menu položka

- `TaskDetailScreen` (`/task/:id`)
- `WorkerTaskDetailScreen` (`/worker/task/:id`)
- `OwnerApartmentDetailScreen` (`/owner/apartments/:id`)
- `SettingsScreen` (`/settings` + pod-routes)
- `ChecklistTemplatesScreen` (`/admin/checklist-templates`)
- Auth/system stránky (`/waiting-room`, `/suspended`, `/payment-required`, `/pin-*`)
