# Architektonický audit: Životní cyklus úkolů a financí

**Datum auditu:** Březen 2026  
**Byznysové pravidlo:** Data musí kaskádovitě propadávat (Katalog → Apartmán → Rezervace → ÚKOL) a v momentě vytvoření úkolu se musí veškerá finanční realita **vypálit** do `tasks.metadata`. Úkol nesmí být závislý na dynamickém dotazování do nadřazených tabulek.

---

## 1. GENEROVÁNÍ ÚKOLŮ

### 1.1 Automatické generování z rezervace (scheduling)

**Místo v kódu:** `lib/features/admin/providers/admin_tasks_provider.dart`, cca řádky 850–902 (smyčka přes `toInsert`).

**Co se NYNÍ zapisuje do metadata:**

| Typ služby | Zapisuje se | NEPÍŠE SE |
|------------|-------------|-----------|
| **transfer_in / transfer_out / transfer** | `amount_to_collect` (jen když `payer_type == 'guest'` a `price > 0`), `flight_number`, `custom_note` | `service_price`, `payer_type` (explicitně) |
| **check_in** | `amount_to_collect`, `collection_breakdown` | `service_price`, `payer_type` |
| **check_out** | `expected_audit_total`, `collection_breakdown` | `service_price`, `payer_type` |
| **cleaning / extra** (ÚKULID – majitelský) | **NIČEMU** | `service_price`, `payer_type`, `amount_to_collect` |

**KRITICKÁ CHYBA:** U úklidu (cleaning) a jiných „extra“ služeb platících majitele se **NEPŘENÁŠÍ** z `reservation_services` do metadata **ANI** `service_price`, **ANI** `payer_type`. Máme tam jen `requires_photo`. Hodnota `price` a `payerGuest` z `c.reservationService` existuje v kódu, ale pro cleaning/extra se nikam nezapisuje.

**Proč to tak je:** Kód má větve jen pro `transfer_*`, `check_in`, `check_out`. Pro ostatní typy (`cleaning`, `extra`) **chybí else větev**, která by zapsala:
- `service_price` = `rs.chargedPrice` (když platí majitel),
- `payer_type` = `rs.payerType ?? 'owner'`.

### 1.2 Manuální vytvoření úkolu (Admin – dialog Nový úkol)

**Místo v kódu:** `lib/features/admin/admin_tasks_screen.dart`, cca řádky 2086–2116.

**Co se NYNÍ zapisuje:**
- **Apartment úkol (!isExternal):** `service_price` z pole _servicePriceController (uživatel zadá ručně). **Chybí** `payer_type` (implicitně owner u bytu).
- **Externí úkol + Personál vybírá hotovost:** `amount_to_collect`. **Chybí** `payer_type` (implicitně guest – inferuje se).
- **Transfer:** `flight_number`, `requires_photo`.

**Shrnutí:** Manuální vytvoření apartment úkolu **ZAPISUJE** `service_price` ✓. Externí s hotovostí zapisuje `amount_to_collect` ✓. `payer_type` se nikde explicitně neukládá – spoléháme na inferenci z `amount_to_collect`.

### 1.3 Pravidelné (scheduled) úkoly bez rezervace

**Místo v kódu:** `lib/features/admin/providers/admin_tasks_provider.dart`, cca řádky 1095–1126.

**Co se NYNÍ zapisuje:** Do metadata **POUZE** `requires_photo`. Žádné `service_price`, `payer_type`, `amount_to_collect`.

**KRITICKÁ CHYBA:** Scheduled úkoly (např. týdenní úklid bez rezervace) nemají vůbec žádnou finanční informaci v metadata.

---

## 2. ODPRACOVÁNÍ ÚKOLU (dokončení)

**Místa v kódu:**
- **Mobil:** `lib/core/database/drift/repositories/drift_task_repository.dart` – `updateTaskStatus`
- **Web (admin):** `lib/core/repositories/task/task_repository_web.dart` – `updateTask`

**Co se zapisuje při dokončení:**
- `status` = `'completed'`
- `completed_at` = aktuální čas
- Volitelně `started_at`, `metadata_overlay` (merge do existujících metadat), `media_urls`

**DŮLEŽITÉ:** Při dokončení se **NEPŘEPISUJÍ** finanční data v metadata. Pokud tam `service_price` / `amount_to_collect` / `payer_type` chybí od vytvoření, zůstávají prázdné. Žádné doplnění z rezervace nebo apartmánu při dokončení.

---

## 3. VÝBĚR HOTOVOSTI (amount_to_collect)

**Místo v kódu:**
- **Dialog:** `lib/features/worker/utils/cash_collection_dialog.dart` – `maybeShowCashCollectionDialog`
- **Uložení:** `lib/core/repositories/cash/cash_wallet_repository.dart` – `recordCashCollection`

**Jak to funguje:**
1. Při dokončení úkolu (mobil) se zkontroluje `metadata['amount_to_collect']` – pokud > 0, zobrazí se dialog.
2. Po potvrzení „ANO, převzal jsem“ se volá `recordCashCollection(taskId, amount, tenantId, profileId, expectedAmount)`.
3. Transakce se zapíše do `employee_cash_transactions` s typem `COLLECTED_FROM_GUEST`.
4. Částka se přičte do `employee_cash_wallets.balance`.

**Zdroj dat:** `expectedAmount` pochází z `metadata['amount_to_collect']` – tedy **z úkolu**. Není to dynamický dotaz. ✓

**NEDOSTATEK:** Pokud metadata nemají `amount_to_collect` (např. u generovaného úklidu, kde to generátor nezapsal), dialog se nezobrazí – i když by měl (např. při manuálním doplnění v budoucnu).

---

## 4. VÝPLATA PERSONÁLU (Payouts / Commissions)

**Místa v kódu:**
- **Uložení výplat:** `lib/core/repositories/settlements/settlement_repository.dart` – `saveSettlement`
- **Zobrazení / výpočet marže:** `lib/features/admin/providers/settlements_provider.dart` – `_taskValueFromRow`
- **Split dialog:** `lib/features/admin/widgets/settlement_split_dialog.dart` – `_totalTaskPrice`

**Z čeho systém počítá hodnotu úkolu:**
- `_taskValueFromRow` a `_totalTaskPrice` čtou **POUZE** z `tasks.metadata`:
  - nejdřív `amount_to_collect`,
  - pak `service_price`,
  - jinak 0.

**DŮSLEDEK:** Admin zadává výplaty a provize ručně v dialogu. „Celková hodnota úkolu“ pro výpočet marže se bere z metadata. Pokud metadata nemají ani `amount_to_collect`, ani `service_price`, zobrazí se **0** – admin nemá vodítko a musí hádat. Žádný fallback na `reservation_services` v tomto modulu.

**Shrnutí:** Výplaty **NEČTOU** dynamicky z nadřazených tabulek. Berou z metadata. Problém je, že metadata často **prázdná jsou** (viz bod 1).

---

## 5. FAKTURACE

**Místo v kódu:** `lib/features/admin/providers/finance_billing_provider.dart`.

** aktuální logika (po předchozích opravách):**
1. Primárně `metadata.service_price`, `metadata.amount_to_collect`, `metadata.payer_type`.
2. Fallback na `reservation_services` (charged_price, payer_type) – přes klíč `reservation_id|service_id`. Mapování jde přes `apartment_services` (apartment_service_id → service_id).
3. Když `apartment_services` záznam neexistuje (byt přeřazen), používá se fallback z `reservation_services` po `reservation_id`.
4. Inferce: `amount_to_collect` > 0 bez explicitního `payer_type` → guest.

**PROBLÉM:** Kvůli chybějícím metadatům u generovaných úkolů (cleaning bez service_price, scheduled bez čehokoli) systém **musí** spoléhat na fallback do `reservation_services` a `apartment_services`. To porušuje pravidlo „úkol nese 100 % svých dat“.

---

## Shrnutí nedostatků

| Fáze | Nedostatek | Důsledek |
|------|------------|----------|
| **Generování z rezervace** | Cleaning/extra nemají v metadata `service_price` ani `payer_type` | Fakturace sahá do reservation_services; při přeřazení bytu mohou být špatné hodnoty |
| **Generování z rezervace** | Transfer/check-in/check-out nemají explicitní `payer_type` | Spoléháme na inferenci z amount_to_collect |
| **Scheduled úkoly** | Žádná finanční data v metadata | Fakturace i settlements mají 0 |
| **Manuální vytvoření** | `payer_type` se nikde explicitně neukládá | Pouze inference; při změně logiky může dojít k chybám |

---

## Doporučení: Sjednocení architektury

### Princip
Při **vytvoření** úkolu (ať už z rezervace, manuálně, nebo scheduled) se **VŽDY** zapíše do `metadata` kompletní finanční snapshot:
- `service_price` – když platí majitel/klient (faktura)
- `amount_to_collect` – když platí host (hotovost)
- `payer_type` – explicitně `'owner'` | `'guest'` | `'client'`

### Konkrétní úpravy

1. **admin_tasks_provider (generování z rezervace):**  
   Přidat větévku pro `cleaning` / `extra` (nebo obecně vše, co není transfer/check_in/check_out):
   - `service_price` = `rs.chargedPrice` (když payer != guest),
   - `amount_to_collect` = `rs.chargedPrice` (když payer == guest),
   - `payer_type` = `rs.payerType ?? 'owner'`.

2. **admin_tasks_provider (scheduled úkoly):**  
   Načíst z `apartment_services` (popř. `tenant_services`) `custom_price` / `default_price` a `payer_type` a zapsat do `scheduledMetadata`.

3. **admin_tasks_screen (manuální vytvoření/úprava):**  
   Explicitně ukládat `payer_type` při ukládání úkolu (owner u bytu, guest když amount_to_collect, client u externího na fakturu).

4. **Všechny downstream moduly (fakturace, settlements):**  
   Primárně číst z metadata. Fallback na reservation_services ponechat jen pro **legacy data**, která už v DB jsou a metadata nemají.

5. **Migrace / ruční oprava:**  
   Pro existující úkoly s prázdnými metadaty viz `docs/LEGACY_BILLING_METADATA_FIX.md` – jednorázový SQL pro doplnění.

---

## Odkazy na kód

| Fáze | Soubor | Řádky / funkce |
|------|--------|-----------------|
| Generování z rezervace | `admin_tasks_provider.dart` | 850–902, `_scheduleTasksFromReservations` |
| Scheduled úkoly | `admin_tasks_provider.dart` | 1095–1126 |
| Manuální vytvoření | `admin_tasks_screen.dart` | 2086–2116, 3232–3257 |
| Dokončení úkolu | `drift_task_repository.dart` | 259–337, `updateTaskStatus` |
| Výběr hotovosti | `cash_wallet_repository.dart` | 41–120, `recordCashCollection` |
| Splitting / settlements | `settlement_split_dialog.dart` | 93–108, `_totalTaskPrice` |
| Fakturace | `finance_billing_provider.dart` | 397–670 |
