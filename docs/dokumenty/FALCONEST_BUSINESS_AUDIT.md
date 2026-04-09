# FalcoNest – Komplexní funkční a byznysový audit

**Datum:** 23. února 2025  
**Typ:** Read-only byznysová analýza  
**Cíl:** Přesný obrázek o tom, co aplikace FalcoNest momentálně reálně umí.

---

## 1. ROLE A UŽIVATELÉ

### 1.1 Definované uživatelské role

Aplikace rozeznává **4 hlavní role**, které určují směrování po přihlášení:

| Role (DB) | Popis | Cílová cesta |
|-----------|-------|--------------|
| `super_admin` | Super Admin (velín nad všemi agenturami) | `/super-admin` |
| `admin` / `manager` | Administrátor / Manažer agentury | `/admin` |
| `property_owner` | Majitel bytu | `/owner` |
| `worker` / `cleaner` / `driver` / `maintenance` / `checkin_agent` | Personál (úklid, převozy, údržba, check-in) | `/worker` |

### 1.2 Hlavní obrazovky po přihlášení

#### Super Admin (`/super-admin`)
- **SuperAdminDashboard** – přehled všech agentur (tenantů)
  - KPI karty (MRR, počet agentur, aktivní)
  - Vyhledávání agentur
  - Seznam agentur s detailním přehledem
  - Megafon – systémové oznámení pro agentury
  - Impersonace – možnost se převtělit do agentury (→ `/admin`)
- **TenantDetailScreen** (`/super-admin/tenant/:id`) – detail jedné agentury
- **AuditLogScreen** (`/super-admin/audit-log`) – globální audit log

#### Admin / Manager (`/admin`)
- **AdminLayout** – IndexedStack s 7 záložkami:
  1. **Dashboard** – přehled úkolů, rezervací, personálu, KPI grafy
  2. **Personál** – správa zaměstnanců, pozvánky, role, týdenní kapacita
  3. **Byty** – správa apartmánů, služeb bytu, majitelé
  4. **Rezervace** – Gantt plachta, Kanban, CRUD rezervací
  5. **Úkoly** – dispečink, Kanban, generování úkolů (smart / scheduled)
  6. **Plánovací kalendář** – týdenní zobrazení úkolů
  7. **Finance** – pokladna zaměstnanců, fakturační podklady

#### Property Owner (`/owner`)
- **OwnerLayout** – IndexedStack se 4 záložkami:
  1. **Byty** – jen byty, u kterých je majitel přiřazen
  2. **Rezervace** – rezervace jeho bytů
  3. **Úkoly** – úkoly vztahující se k jeho bytům
  4. **Kalendář** – plánovací kalendář pro jeho byty

- **OwnerApartmentDetailScreen** (`/owner/apartments/:id`) – detail apartmánu včetně služeb a cen

#### Worker / Personál (`/worker`)
- **WorkerDashboardScreen** – seznam dnešních úkolů (Kanban podle stavu)
- **WorkerTaskDetailScreen** (`/worker/task/:id`) – detail úkolu s akcemi
- Specializované obrazovky podle typu úkolu:
  - Úklid (`cleaning_task_screen`)
  - Check-in (`checkin_task_screen`)
  - Check-out (`checkout_task_screen`)
  - Transfer (`transfer_task_screen`)
  - Údržba (`maintenance_task_screen`)
  - Materiál (`material_task_screen`)
  - Hlášení problému (`issue_task_screen`)
  - Výchozí (`default_task_screen`)

---

## 2. HLAVNÍ MODULY A FUNKCE

### 2.1 Správa apartmánů (Admin)

**AdminApartmentsScreen** – plnohodnotná správa:

- **Evidované údaje bytu:**
  - Název, adresa
  - Zóna (oblast)
  - Check-in / check-out čas
  - Standardní délka úklidu (minuty)
  - Poznámky majitele
  - Fotka (URL)

- **Služby bytu (apartment_services):**
  - Přiřazení služeb z katalogu (`tenant_services`)
  - Trigger typ: `before_checkin`, `after_checkout`, `both_ways`, `on_demand`, `scheduled`
  - `schedule_interval` pro pravidelné úkoly
  - Vlastní cena (`custom_price`) vs. výchozí z katalogu
  - Plátce: `guest` (host platí na místě) nebo `owner` (majitel faktura)

- **Majitelé bytu (apartment_owners):**
  - Přidání existujícího majitele (profile s `role=property_owner`)
  - Pozvání nového majitele e-mailem

- **Stav bytu:** Uklizeno, K úklidu, Obsazeno hosty, Probíhá úklid, Rekonstrukce

### 2.2 Rezervace (Admin)

**AdminReservationsScreen** – komplexní správa:

- **Gantt plachta (ReservationTimeline):**
  - Mřížka dnů × apartmány
  - Pruhy rezervací s hostem, počtem hostů, poznámkami
  - Klik na prázdnou buňku → nová rezervace s předvyplněním bytu a data

- **CRUD rezervací:**
  - Vytvoření, úprava, mazání (soft delete)
  - Pole: guest_name, guest_phone, guest_adults, guest_children, start_date, end_date
  - Status: new, confirmed, checked_in, checked_out, cancelled
  - Kanban pro přetahování mezi stavy

- **Služby rezervace (reservation_services):**
  - Přiřazení služeb ke konkrétní rezervaci (např. úklid, transfer, check-in)
  - Vlastní cena (`charged_price`), plátce (`guest` / `owner`)

### 2.3 Úkoly / Dispečink (Admin)

**AdminTasksScreen** – dispečerské centrum:

- **Typy úkolů:**
  - Úklid, Check-in, Check-out, Transfer, Údržba, Jiné
  - Každý typ má vlastní ikonu a vizuál

- **Kanban:**
  - Sloupce: Návrh, Nový, Probíhá, Hotovo, Problém
  - Drag & drop pro změnu stavu

- **Generování úkolů:**
  - **Smart tasks** – z rezervací podle `apartment_services` (trigger_type, služby, metadata)
  - **Scheduled tasks** – pravidelné úkoly podle `schedule_interval`
  - Automatické přiřazení personálu (role, zóny, absence, kapacita)

- **Ruční úkoly:**
  - Přidání úkolu přes formulář (apartmán, personál, termín, typ)

- **Plánovací kalendář:**
  - Týdenní zobrazení úkolů
  - Přetahování, úprava přiřazeného

### 2.4 Tým / Zaměstnanci (Admin)

**AdminTeamScreen** – správa personálu:

- **Evidované údaje:**
  - Jméno, e-mail
  - Role: admin / worker
  - Pracovní pozice (roles): cleaner, driver, maintenance, checkin_agent
  - Týdenní kapacita (weekly_hours)
  - Termíny smlouvy (start_date, end_date)
  - Preference zón
  - Pozvánky (pending) vs. aktivní profily

- **Správa:**
  - CRUD zaměstnanců
  - Pozvánky na e-mail s rolí

### 2.5 Finance / Pokladna (Admin)

**FinanceDashboardScreen** – zaměstnanecká pokladna:

- **Evidované záznamy:**
  - „Kapsa“ každého zaměstnance – zůstatek (balance)
  - Hotovost k vybrání na úkolech (check-in, check-out, transfer)
  - Potvrzení převzetí v kanceláři (nulování kapsy)

- **Kritické alerty:**
  - Úkoly, kde pracovník nepotvrdil výběr hotovosti

- **FinanceBillingScreen** (modul `finance_export`):
  - Měsíční přehled služeb u ukončených rezervací
  - Agregace podle plátce (host vs. majitel)

---

## 3. BYZNYSOVÁ LOGIKA

### 3.1 Provázání Apartmány → Služby → Rezervace → Úkoly

```
Apartments (byty)
  ├── apartment_services (služby bytu – odkaz na katalog tenant_services)
  │   └── trigger_type, schedule_interval, custom_price, payer_type
  ├── apartment_owners (majitelé)
  ├── reservations (rezervace)
  │   └── reservation_services (služby při rezervaci)
  │       └── charged_price, payer_type, apartment_service_id
  └── tasks (úkoly)
      ├── apartment_id, reservation_id, service_id
      └── assigned_to (personál)
```

### 3.2 Generování úkolů (automatické vs. ruční)

- **Automatické (Smart tasks):**
  - Na základě rezervací a `apartment_services`
  - Trigger: před check-inem, po check-outu, obojí, na požádání
  - Kontrola duplicit
  - Přiřazení personálu podle role, zón, absence, kapacity

- **Automatické (Scheduled tasks):**
  - Pravidelné úkoly podle `schedule_interval` (např. „každých 7 dní“)
  - Bez vazby na rezervaci
  - Ochranný štít: nepřidá úkol, pokud už existuje aktivní pro apartment+service

- **Ruční:** Přes formulář Add Task v AdminTasksScreen

### 3.3 Ceníky a účtování

- ** tenant_services (katalog):**
  - Název, typ služby, výchozí cena (`default_price`)
  - `required_role` pro přiřazení personálu

- **apartment_services:**
  - Vlastní cena (`custom_price`) nebo výchozí z katalogu
  - `payer_type`: `guest` (host platí na místě) nebo `owner` (majitel faktura)

- **reservation_services:**
  - `charged_price` – finální cena služby
  - `payer_type` – rozlišení pro finance (host vs. majitel)

- **Finance:**
  - Agregace podle `payer_type`
  - Host = hotovost k vybrání při check-in/out
  - Majitel = podklad k fakturaci

---

## 4. BÍLÁ MÍSTA A NEDODĚLKY

### 4.1 Placeholder a „Coming soon“ v UI

| Položka | Umístění | Chování |
|---------|----------|---------|
| `/home` | Router | `PlaceholderScreen` – jen název aplikace, odhlášení |
| warehouse, smart_lock, automation, automatic_tasks | Admin sidebar (ModuleIconMapper) | `tabIndex: null` → po kliknutí SnackBar „Coming soon“ |
| Admin moduly bez licence | Sidebar | Zobrazeny jako zamčené (🔒), toast o zamčení |

### 4.2 Zakomentované / odložené funkce

- **Platební brána** (`/payment-success`, `/payment-cancel`) – routy zakomentované v `app_router.dart`
- Finance modul – vyžaduje aktivní `finance` v tenant_modules; export fakturace vyžaduje `finance_export`

### 4.3 Moduly bez obrazovky

- `warehouse` – sklad (ikona + label v menu, žádná obrazovka)
- `smart_lock` – chytré zámky
- `automation` – automatizace
- `automatic_tasks` – automatické úkoly (částečně – smart/scheduled existují v AdminTasksScreen)

### 4.4 Možné nedokončené byznysové procesy

1. **Platební flow** – routy pro Stripe success/cancel jsou odloženy
2. **Fakturace majitelům** – finance_export dává agregace, ale není jasné, zda existuje generování faktur
3. **Offline-first** – implementace v průběhu (PendingMutationLocal, optimistic UI)
4. **Modulový systém** – některé moduly mají jen paywall/upsell, bez plné implementace

### 4.5 Technické poznámky (bez změny chování)

- `task_assignment_engine.dart` – zamčený soubor (neanalyzován)
- RLS (Row Level Security) pro multi-tenant izolaci
- Lokalizace přes `easy_localization` (cs.json, en.json)
- PIN pro mobilní odemčení

---

## 5. SHRNUTÍ – CO FALCONEST MOMENTÁLNĚ JE A UMÍ

| Oblast | Stav |
|--------|------|
| **Role a směrování** | Plně implementované (Super Admin, Admin, Owner, Worker) |
| **Správa apartmánů** | Plná (CRUD, služby, majitelé, stavy) |
| **Rezervace** | Plná (Gantt, Kanban, CRUD, služby, plátce) |
| **Úkoly a dispečink** | Plný (Smart + Scheduled generování, Kanban, ruční úkoly) |
| **Personál** | Plná správa (role, kapacita, pozvánky) |
| **Finance – pokladna** | Implementovaná (kapsy, výběr, alerty) |
| **Finance – fakturace** | Měsíční agregace (modul finance_export) |
| **Plánovací kalendář** | Implementovaný (Admin + Owner) |
| **Worker mobilní app** | Plná (úkoly, typy úkolů, výběr hotovosti) |
| **Sklad, Smart lock, Automation** | Pouze „Coming soon“ |
| **Platební brána** | Odloženo |

---

*Report vznikl jako read-only analýza codebase. Žádný kód nebyl měněn.*
