# FalcoNest – Audit UI/UX architektury Admin modulu

**Datum:** 23. února 2025  
**Typ:** Read-only analýza (žádné změny kódu)  
**Účel:** Připravenost na vizuální facelift (tmavý sidebar, moderní SaaS vzhled, branding).

---

## 1. STRUKTURA LAYOUTU A MENU

### Hlavní soubor
- **`lib/features/admin/admin_layout.dart`** – řídí celé rozložení administrace

### Technické řešení
- **Responzivní layout:** Práh 800 px (`_breakpointWidth`)
  - **Široké obrazovky (≥ 800 px):** `_WideLayout` – `Row` se stálým levým panelem + obsah
  - **Úzké obrazovky (< 800 px):** `_NarrowLayout` – `Scaffold` s `AppBar` (hamburger) + `Drawer`

### Levé menu
- **Není** `NavigationRail` ani standardní `Drawer` layout
- **Vlastní widget:** `_AdminSidebar` – `SizedBox(width: 240)` + `Column` s `ListTile` položkami
- Položky menu pocházejí z katalogu modulů (`allModulesProvider`, `ModuleIconMapper`)
- Menu vykresluje **tentýž soubor:** `admin_layout.dart` (řádky 354–447)

### Shrnutí
| Aspekt | Hodnota |
|--------|---------|
| Soubor layoutu | `admin_layout.dart` |
| Sidebar widget | `_AdminSidebar` (vnitřní třída) |
| Šířka sidebaru | 240 px |
| Přepínač Drawer/Sidebar | `LayoutBuilder` + `constraints.maxWidth >= 800` |

---

## 2. TOP BAR A BRANDING

### Aktuální stav
- **Široké obrazovky (`_WideLayout`):** **Žádná horní lišta** – obsah začíná hned pod eventuálními bannery
- **Úzké obrazovky (`_NarrowLayout`):** `AppBar` s:
  - `title: Text('admin.title'.tr())` („FalcoNest“ nebo lokalizovaný ekvivalent)
  - `leading:` hamburger ikona
  - `actions:` logout / zpět do velína (při převtělení)

### Bannery nad obsahem (všechny šířky)
1. **`_ImpersonationBanner`** – zobrazuje se pouze při režimu převtělení (Super Admin)
2. **`_SystemAnnouncementBanner`** – zobrazuje `system_announcement` tenanta (modré pozadí)

### Název agentury (Tenant name)
- Provider: **`currentTenantNameProvider`** (`lib/features/admin/providers/current_tenant_name_provider.dart`)
- Použití: Pouze v `_ImpersonationBanner` při převtělení – **není vidět v normálním Admin režimu**

### Ideální místa pro branding
| Umístění | Soubor | Poznámka |
|---------|--------|----------|
| Horní lišta napříč obsahem | `admin_layout.dart` – nový widget nad `body` | Široké obrazovky nemají AppBar – musela by se přidat globální hlavička |
| V Sidebaru | `_AdminSidebar` – nyní jen `Text('admin.title')` (ř. 386–391) | Vhodné pro logo + název agentury |
| V AppBar (úzké) | `_NarrowLayout` – `AppBar(title: ...)` | Rozšířit o tenant name vedle titulku |

---

## 3. SPRÁVA BAREV A TÉMAT (Theming)

### Centrální ThemeData
- **`lib/app.dart`** – jediná definice:
  ```dart
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    useMaterial3: true,
  ),
  ```
- **Žádný** `lib/core/theme/` – tematizace je minimální

### Použití tématu vs. hardcoded barvy
- **Theme se používá jen částečně:**
  - `Theme.of(context).colorScheme.primary` – v `_ModuleNavItem`, TabBar
  - `Theme.of(context).textTheme` – headlineSmall, bodyLarge, atd.
- **Většina barev je hardcoded:**
  - `Colors.white`, `Colors.grey.shade600`, `Colors.orange.shade700`, `Colors.red.shade400`
  - `Color(0xFFF5F5F5)` – pozadí Scaffoldu (admin_apartments, admin_team, admin_dashboard, admin_tasks, admin_reservations, admin_zones)
  - `Color(0xFF1565C0)` – modrá v admin_tasks (status barvy)
  - `Colors.deepOrange` – impersonation banner
  - `Colors.blue.shade700` – system announcement

### „Modro-oranžová“ paleta
- **Žádný centrální soubor** – barvy jsou rozptýlené v jednotlivých widgetech
- Typické kombinace: `Colors.blue`, `Colors.orange.shade700`, `Colors.green`, `Colors.red`
- `admin_tasks_screen.dart` – vlastní konstanty: `_statusDraft`, `_statusNew`, `_statusInProgress`, `_statusDone`, `_statusProblem`

### Shrnutí
| Aspekt | Hodnota |
|--------|---------|
| Centrální paleta | Neexistuje |
| Theme seed | `Colors.deepPurple` (ne modro-oranžová) |
| scaffoldBackgroundColor | Hardcoded `Color(0xFFF5F5F5)` v každém Admin screenu |
| Počet hardcoded barev | Stovky výskytů v `lib/features/admin/` |

---

## 4. SDÍLENÉ UI KOMPONENTY (Karty a modaly)

### Existující sdílené komponenty
- **Žádný** globální `AppCard` ani `BaseCard` widget
- Každá obrazovka má vlastní privátní karty:

| Obrazovka | Karta widget | Implementace |
|-----------|--------------|--------------|
| Dashboard | `_KpiCard` | `Container` + `BoxDecoration(color: Colors.white, borderRadius: 12, boxShadow)` |
| Apartments | `_ApartmentCard` | `Container` / `Card` |
| Tasks | `_TaskCard` | `Card` |
| Reservations | `_KanbanReservationCard`, `_ReservationCard` | `Card` |
| Team | `_MemberCard`, `_OwnerCard` | `Container` / `Card` |
| Finance | `_WalletCard`, `_FailedCashAlertCard` | `Card` |
| Wallet Top-up | `_PackageCard` | vlastní |

### Styl karet
- **`_KpiCard`** (dashboard): `color: Colors.white`, `borderRadius: 12`, `boxShadow: blurRadius 10`
- Ostatní: mix `Card()`, `Container(decoration: BoxDecoration(...))`
- Border radius: 8, 10, 12, 16 – **nekonzistentní**

### Modaly a dialogy
- Všude `showDialog` + `AlertDialog` / `SimpleDialog`
- Žádný wrapper pro jednotný vzhled – `AlertDialog`, `borderRadius: 16` jen u `premium_upsell_dialog`

### Odpověď na otázku: „50 míst nebo jedno?“
- **Musíme měnit na desítkách míst**
- Karty: `_KpiCard`, `_ApartmentCard`, `_TaskCard`, `_MemberCard`, `_OwnerCard`, `_KanbanReservationCard`, `_ReservationCard`, `_WalletCard`, `_FailedCashAlertCard`, `_PackageCard`
- Plus desítky `Container(decoration: BoxDecoration(...))` napříč formuláři
- **Bez refaktoru na společný `AppCard`** nebude globální změna stínu a radiusu možná z jednoho místa

---

## SOUHRN – Připravenost na facelift

| Oblast | Stav | Doporučení |
|--------|------|-------------|
| **Layout & Menu** | Dobře strukturované v jednom souboru | Sidebar lze obarvit v `_AdminSidebar` |
| **Top Bar / Branding** | Chybí na širokých obrazovkách | Přidat globální top bar nad `body` v `admin_layout.dart` |
| **Barvy & Téma** | Rozptýlené, téměř žádná centralizace | Založit `lib/core/theme/app_theme.dart`, migrovat barvy do `ThemeData` |
| **Karty** | Žádná sdílená komponenta | Vytvořit `AppCard` a postupně nahradit privátní karty |

### Klíčové soubory pro facelift
1. **`lib/features/admin/admin_layout.dart`** – sidebar, top bar, layout
2. **`lib/app.dart`** – ThemeData, colorScheme
3. **`lib/features/admin/admin_dashboard_screen.dart`** – _KpiCard jako reference pro nový AppCard
4. **`lib/features/admin/admin_apartments_screen.dart`** – _ApartmentCard, _TopActionBar
5. **`lib/features/admin/admin_tasks_screen.dart`** – _TaskCard, _TopActionBar
6. **`lib/features/admin/admin_reservations_screen.dart`** – _TopActionBar, karty
7. **`lib/features/admin/admin_team_screen.dart`** – _MemberCard, _OwnerCard
8. **`lib/features/admin/finance_dashboard_screen.dart`** – _WalletCard, _FailedCashAlertCard
