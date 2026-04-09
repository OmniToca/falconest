# Hloubkový architektonický audit – FalcoNest Admin & Super Admin

**Datum:** 21. 2. 2026  
**Rozsah:** `lib/features/admin/` a `lib/features/super_admin/`  
**Účel:** Identifikace technologického dluhu před přesunem na mobilní offline-first fázi

---

## 1. Architektura a adresářová struktura

### 1.1 Aktuální struktura

```
lib/features/admin/
├── models/ (6 souborů)
├── providers/ (15 souborů)
├── utils/ (1 soubor)
└── admin_*.dart screens (7 souborů)

lib/features/super_admin/
├── providers/ (4 soubory)
├── services/ (2 soubory)
├── utils/ (1 soubor)
└── *.dart screens/modals (7 souborů)
```

### 1.2 „Frankenstein“ komponenty (míchání admin + super_admin)

| Soubor | Řádky | Problém |
|--------|-------|---------|
| `admin/admin_layout.dart` | 89, 366, 397–400 | Obsahuje `role == 'super_admin'` a `tenantIdForData == null` – logika pro obě role v jednom layoutu. Modulární sidebar (`_ModuleNavItem`) zobrazuje ghost móduly pro Super Admina. |
| `admin/providers/module_provider.dart` | 118–123 | `isModuleActive()` – Super Admin bypass: `if (isSuperAdmin) return true` přímo v provideru pro Tenant moduly. |
| `super_admin/tenant_detail_screen.dart` | 256–260 | Invaliduje admin providery (`adminTasksProvider`, `adminReservationsProvider`, `apartmentsProvider`, `adminTeamProvider`) po impersonaci – silná vazba na admin vrstvu. |
| `super_admin/super_admin_dashboard.dart` | 1449–1455 | Stejná invalidace admin providerů po impersonaci. |
| `super_admin/tenant_command_modal.dart` | – | Importuje `admin/models/module_model`, `admin/utils/module_icon_mapper`, `admin/providers/module_provider` – sdílení je rozumné, ale vytváří vazbu. |
| `super_admin/module_subscription_dialog.dart` | – | Importuje admin modely a utilit. |

**Závěr:** Admin layout a module_provider explicitně řeší roli Super Admina. Super Admin obrazovky závisí na admin providerech (kvůli impersonaci a zobrazení dat tenanta). Čisté oddělení rolí není splněno.

---

## 2. State Management (Riverpod)

### 2.1 Provider soubory

**Admin:**  
`admin_reservations_provider`, `admin_team_provider`, `admin_tasks_provider`, `apartments_provider`, `zones_provider`, `module_provider`, `current_tenant_name_provider`, `apartment_status_provider`, `apartment_services_options_provider`, `task_categories_provider`, `apartment_services_repository`, `reservation_services_repository`

**Super Admin:**  
`all_tenants_provider`, `tenant_detail_provider`, `dashboard_mrr_provider`, `audit_log_provider`

### 2.2 autoDispose

- **Žádné použití `autoDispose`** v admin ani super_admin providerech.
- Riziko: dlouhodobě žijící stavy po opuštění obrazovky, zejména u velkých dat.

### 2.3 Globální vs Family providery

| Typ | Příklady |
|-----|----------|
| Globální | `adminTeamProvider`, `adminTasksProvider`, `adminReservationsProvider`, `apartmentsProvider`, `allTenantsProvider`, `dashboardMrrProvider` |
| Family | `tenantDetailProvider(tenantId)`, `tenantActiveModuleIdsProvider(tenantId)`, `apartmentStatusProvider(apartmentId)` |

### 2.4 Rizika

1. `adminTasksProvider` – velký AsyncNotifier, bez autoDispose.
2. `allTenantsProvider` – načítá všechny tenanty, bez autoDispose.
3. `currentTenantWithRealtimeProvider` – drží realtime subscription, bez autoDispose.
4. `admin_reservations_provider` – komplexní stav rezervací.

---

## 3. Multi-tenant bezpečnost

### 3.1 Dotazy s explicitním `tenant_id`

- `apartments_provider.dart` – `.eq('tenant_id', tenantId)`
- `admin_team_provider.dart` – `.eq('tenant_id', tenantId)`
- `admin_tasks_provider.dart` – `.eq('tenant_id', tenantId)`
- `zones_provider.dart` – `.eq('tenant_id', tenantId)`
- `module_provider.dart` – tenant_modules (join s tenant kontextem)
- `tenant_detail_provider.dart` – `.eq('tenant_id', tenantId)` u tenant‑specifických dotazů

### 3.2 Dotazy bez explicitního `tenant_id` (spoléhání na RLS)

| Soubor | Řádek | Operace | Poznámka |
|--------|-------|---------|----------|
| `admin_tasks_screen.dart` | 387–390 | `tasks.update().eq('id', taskId)` | Chybí `.eq('tenant_id', tenantId)` – závislost na RLS. |
| `admin_tasks_screen.dart` | 1964–1973 | `tasks.update().eq('id', widget.task.id)` | Chybí explicitní tenant_id. |
| `admin_tasks_screen.dart` | 1473 | `tasks.insert` | Obsahuje `'tenant_id': tenantId` v payload – OK. |
| `admin_reservations_screen.dart` | 1451+ | `reservations.update` | Nutno ověřit přítomnost tenant_id v podmínce nebo payload. |
| `admin_team_screen.dart` | 1150, 1444 | `staff_absences.insert`, `invitations.insert` | Nutno ověřit, zda payload vždy obsahuje `tenant_id`. |

**Závěr:** Většina dotazů používá `tenant_id` buď v filtru, nebo v payload. Některé UPDATE/DELETE spoléhají jen na RLS. Doporučení: doplnit explicitní `tenant_id` tam, kde chybí, pro defense in depth.

---

## 4. i18n – hardcodované texty

### 4.1 Admin – `admin_tasks_screen.dart`

| Řádek | Text | Typ |
|-------|------|-----|
| 1445 | `Text('Vyberte apartmán')` | Validation |
| 1456 | `Text('Vyberte termín (datum a čas)')` | Validation |
| 1489 | `Text('Úkol byl uložen')` | Success |
| 1502 | `Text('Chyba: ${e.message}')` | Error |
| 1511 | `Text('Chyba: $e')` | Error |
| 1585 | `Text('Vyberte apartmán')` | Validation (duplicita) |
| 1623 | `Text('Nikdo')` | Dropdown label |
| 1943 | `Text('Vyberte termín (datum a čas)')` | Validation (duplicita) |
| 1980 | `Text('Úkol byl uložen')` | Success (duplicita) |
| 1989 | `Text('Chyba: ${e.message}')` | Error (duplicita) |
| 1998 | `Text('Chyba: $e')` | Error (duplicita) |
| 2080 | `Text('Vyberte apartmán')` | Validation (duplicita) |
| 2118 | `Text('Nikdo')` | Dropdown label (duplicita) |

**Celkem:** 13 výskytů hardcodovaných českých textů v jednom souboru.

### 4.2 Super Admin – `tenant_detail_screen.dart`

| Řádek | Text | Typ |
|-------|------|-----|
| 296 | `Text('Agentura nenalezena')` | Error fallback |
| 299 | `Text('Agentura nenalezena')` | Error fallback |
| 437, 440, 1381, 1385 | `Text('$e')` | Zobrazení výjimky – přijatelné pro debugging |

### 4.3 Ostatní

- `super_admin_settings_modal.dart` ř. 190, 926 – dynamický obsah (`$flag $label`, `${currency.code}`) – OK.
- `tenant_command_modal.dart` ř. 1135 – dynamický obsah – OK.

---

## 5. Technologický dluh – kritické body

### 5.1 Soubory nad 500 řádků

| Soubor | Řádků | Priorita |
|--------|-------|----------|
| `admin_reservations_screen.dart` | **3803** | Kritická |
| `admin_team_screen.dart` | **2278** | Kritická |
| `admin_tasks_screen.dart` | **2204** | Kritická |
| `admin_apartments_screen.dart` | **2115** | Kritická |
| `admin_dashboard_screen.dart` | 1332 | Vysoká |
| `providers/admin_tasks_provider.dart` | 1284 | Vysoká |
| `tenant_detail_screen.dart` | **1537** | Kritická |
| `super_admin_dashboard.dart` | **1482** | Kritická |
| `tenant_command_modal.dart` | 1230 | Vysoká |
| `super_admin_settings_modal.dart` | 947 | Střední |
| `providers/all_tenants_provider.dart` | 655 | Střední |
| `audit_log_screen.dart` | 624 | Střední |
| `admin_layout.dart` | 595 | Střední |

### 5.2 Top 5 kritických míst pro refaktoring

1. **`admin_reservations_screen.dart` (3803 řádků)**  
   - Jeden obří soubor s formulářem, validační logikou, kolizemi, timeline a list view.  
   - Duplicitní kód pro create/edit rezervaci.  
   - Chybí české komentáře u složitější logiky (např. collision detection).  
   - **Doporučení:** Rozdělit na `ReservationForm`, `ReservationTimeline`, `ReservationList`, `ReservationCollisionHandler`.

2. **`admin_tasks_screen.dart` (2204 řádků)**  
   - 13 hardcodovaných českých textů.  
   - Duplicitní logika pro přidání a úpravu úkolu (téměř totožné bloky).  
   - `tasks.update().eq('id')` bez explicitního `tenant_id`.  
   - **Doporučení:** i18n klíče, sdílená metoda pro save úkolu, doplnit tenant_id.

3. **`admin_team_screen.dart` (2278 řádků)**  
   - Velký počet vnořených widgetů a stavů.  
   - Opakované vzory validace a snackbarů.  
   - **Doporučení:** Extrakce `_MemberCard`, `_InviteDialog`, `_AbsenceDialog` do samostatných souborů.

4. **`super_admin/tenant_detail_screen.dart` (1537 řádků)**  
   - Kombinuje billing, moduly, tým, statistiky a další sekce.  
   - Hardcodované „Agentura nenalezena“.  
   - Přímá závislost na admin providerech.  
   - **Doporučení:** Rozdělit na `TenantBillingSection`, `TenantModulesSection`, `TenantTeamSection`.

5. **`admin/providers/admin_tasks_provider.dart` (1284 řádků)**  
   - Generování úkolů, scheduled tasks, blokace kalendáře.  
   - Složitá logika bez dostatečných komentářů.  
   - **Doporučení:** Rozdělení na `TaskGenerationService`, `ScheduleBlocker`, samostatné providery pro generování a seznam.

### 5.3 Duplicitní vzory

1. **Kontrola role:**  
   `ref.watch(authNotifierProvider).state.role == 'super_admin'` – opakováno na několika místech.

2. **Validace tenant_id:**  
   `if (tenantId == null || tenantId.isEmpty) return []` – opakováno v řadě providerů.

3. **Invalidace po impersonaci:**  
   `ref.invalidate(adminTasksProvider); ref.invalidate(adminReservationsProvider); ...` – stejný řetězec na více místech.

4. **Validační/Snackbar bloky v `admin_tasks_screen.dart`:**  
   Téměř identický kód v create a edit úkolu.

### 5.4 Chybějící české komentáře

- `admin_reservations_screen.dart` – collision detection, date change flow.  
- `admin_tasks_provider.dart` – `taskBlockDurationMinutes`, `_resolveTaskType`, generování scheduled tasks.  
- `tenant_command_modal.dart` – logika přepínání modulů a kaskád.  
- `all_tenants_provider.dart` – složitá agregace tenantů a MRR.

---

## 6. Shrnutí a doporučení

### Kritické

1. **i18n v admin_tasks_screen.dart** – 13 hardcodovaných českých řetězců.  
2. **Rozdělení obřích obrazovek** – reservations (3803), team (2278), tasks (2204), apartments (2115).  
3. **Explicitní tenant_id** – doplnit tam, kde chybí (UPDATE/DELETE v tasks, reservations).

### Vysoká priorita

4. **autoDispose u providerů** – zejména u velkých a realtime providerů.  
5. **Oddělení admin/super_admin** – společné rozhraní nebo vrstva místo přímých importů a if/else na roli.  
6. **České komentáře** – u složité logiky v providerech a obrazovkách.

### Střední priorita

7. **Sdílené utility** – role check, tenant validation, invalidace.  
8. **Refaktoring duplicit** – create/edit úkolu, validační bloky.

---

*Report generován na základě statické analýzy kódu. Doporučuje se ověření RLS politik v Supabase a manuální testování impersonace.*
