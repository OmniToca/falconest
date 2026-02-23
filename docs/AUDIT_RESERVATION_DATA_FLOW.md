# Audit report: Datový tok při vytváření rezervace

**Datum auditu:** 21. 2. 2025  
**Soubory analyzované:** `admin_reservation_forms.dart`, `reservation_services_repository.dart`, `admin_reservations_provider.dart`, Supabase migrace

---

## 1. MAPOVÁNÍ POLÍ – formulář → databáze

### Tab 1 „Detaily pobytu“ (AddReservationDialog)

| Pole ve formuláři | Controller / proměnná | Sloupec v DB | Tabulka | Mapování |
|------------------|-----------------------|--------------|---------|----------|
| Byt | `_selectedApartmentId` | `apartment_id` | reservations | ✓ Přímé |
| Jméno hosta | `_guestNameController` | `guest_name` | reservations | ✓ trim, prázdné → null |
| Telefon hosta | `_guestPhoneController` | `guest_phone` | reservations | ✓ trim, prázdné → null |
| Zdroj rezervace | `_reservationSource` | `reservation_source` | reservations | ✓ Booking/Airbnb/Direct/Other |
| Počet dospělých | `_guestAdultsController` | `guest_adults` | reservations | ✓ int, default 0 |
| Počet dětí | `_guestChildrenController` | `guest_children` | reservations | ✓ int, default 0 |
| Období pobytu | `_dateRange` (DateTimeRange) | `start_date`, `end_date` | reservations | ✓ Formát yyyy-MM-dd |
| Čas příjezdu | `_arrivalTimeController` | `arrival_time` | reservations | ✓ timestamp UTC (viz níže) |
| Čas odjezdu | `_departureTimeController` | `departure_time` | reservations | ✓ timestamp UTC (viz níže) |
| Interní poznámka | `_internalNoteController` | `internal_note` | reservations | ✓ trim, prázdné → null |

**Nepředává se z UI (hardcoded):**
- `needs_transfer` = `false` (legacy; služby jdou přes reservation_services)
- `tenant_id` = z `authNotifierProvider.tenantIdForData` (ne z formuláře, ale z auth)

### Tab 2 „Služby a požadavky“

| Pole ve formuláři | Edit state | Sloupec v DB | Tabulka | Mapování |
|-------------------|------------|--------------|---------|----------|
| Zaškrtnutí služby | `ReservationServiceEditState.enabled` | (pouze enabled → insert) | reservation_services | ✓ |
| Účtovaná cena | `chargedPriceEur` | `charged_price` | reservation_services | ✓ V EUR (převod měny v UI) |
| Vlastní poznámka | `customNote` | `custom_note` | reservation_services | ✓ trim |
| Kdo platí | `payerType` | `payer_type` | reservation_services | ✓ owner / guest |

**Každý záznam reservation_services obsahuje také:**
- `tenant_id` – z parametru `saveForReservation(tenantId: tenantId)`
- `reservation_id` – nové ID z prvního insertu
- `apartment_service_id` – z `ReservationServiceEditState.apartmentServiceId`

---

## 2. ZAPOMENUTÁ DATA / RIZIKA

### ⚠️ Status nové rezervace

- **Problém:** Při **INSERT** nové rezervace se do payloadu **neposílá** `status`.
- **Kód:** Payload v AddReservationDialog (ř. 213–230) nemá klíč `status`.
- **Důsledek:** Záleží na DB – pokud sloupec `status` nemá `DEFAULT 'new'`, může být `NULL` nebo dojde k chybě.
- **Doporučení:** Ověřit migraci tabulky `reservations` – pokud chybí `DEFAULT`, doplnit `status: 'new'` do payloadu.

### ✓ Všechna ostatní pole z Tabu 1

Všechna pole z Tabu 1 se dostanou do `.insert()` – žádná ztráta dat.

### ✓ Služby (Tab 2)

`saveForReservation` bere všechny enabled služby ze `_servicesState` a zapisuje je do `reservation_services` včetně `charged_price`, `custom_note`, `payer_type`. Žádné zapomenuté pole.

### ⚠️ Prázdné časy příjezdu/odjezdu

- **Chování:** Pokud uživatel nevybere čas (TimePicker), `_arrivalTimeController` resp. `_departureTimeController` zůstanou prázdné.
- **Kód:** `arrivalTimeUtc` a `departureTimeUtc` jsou pak `null` → do payloadu jde `'arrival_time': null`, `'departure_time': null`.
- **Důsledek:** V DB jsou NULL, což je akceptovatelné. Kontrola kolizí používá výchozí časy (15:00 příjezd, 10:00 odjezd) z ř. 127–131.
- **Shrnutí:** Funkčně v pořádku, ale při prázdných časech se do DB neukládá žádný konkrétní čas.

---

## 3. MULTI-TENANT

### ✓ Reservations

- `tenant_id` se bere z `ref.read(authNotifierProvider).tenantIdForData`.
- Kontrola před insertem (ř. 179–182): pokud je `tenantId` null nebo prázdný, vyhodí se výjimka – insert se neprovede.
- Hodnota se vždy zapisuje do payloadu: `'tenant_id': tenantId`.

### ✓ Reservation_services

- `saveForReservation` dostává `tenantId` jako parametr a zapisuje ho do každého řádku: `'tenant_id': tenantId`.
- RLS v migracích vyžaduje `tenant_id = my_tenant_id()` pro INSERT.

### ✓ Update (EditReservationDialog)

- Update rezervace používá `.eq('tenant_id', tenantId)` – operace je omezena na tenanta.

**Závěr:** Multi-tenant je dodržen, `tenant_id` se vkládá explicitně a je ověřován před zápisem.

---

## 4. ČASOVÁ KONZISTENCE (UTC)

### Příjezd a odjezd

**Kód (ř. 190–210):**

```dart
arrivalTimeUtc = DateTime(_dateRange!.start.year, ..., h, m, 0).toUtc();
departureTimeUtc = DateTime(_dateRange!.end.year, ..., h, m, 0).toUtc();
```

- `DateTime(...)` bez timezone vytváří lokální čas.
- `.toUtc()` převede na UTC – správné uložení do `timestamptz`.
- Do payloadu se posílá ISO string: `arrivalTimeUtc?.toIso8601String()`, `departureTimeUtc?.toIso8601String()`.

**Závěr:** ✓ Data příjezdu a odjezdu jsou před odesláním správně převedena na UTC.

### start_date a end_date

- Ukládají se jako řetězce ve formátu `yyyy-MM-dd` (ř. 119–120).
- Žádný čas ani timezone – čistá data. Vhodné pro sloupce typu DATE.

**Závěr:** ✓ Žádný problém s časovými pásmy.

### reservation_services

- Nepracují s časovými údaji; ukládají ceny, poznámky a plátce.
- Žádná závislost na UTC.

---

## 5. SOUHRN RIZIK A DOPORUČENÍ

| Riziko | Závažnost | Doporučení |
|--------|-----------|------------|
| Chybějící `status` při INSERT | střední | Ověřit DB schéma a při absenci DEFAULT doplnit `status: 'new'` do payloadu |
| Prázdné arrival/departure čas | nízká | Zvážit výchozí časy (15:00 / 10:00) a ukládat je i při nevyplnění |
| needs_transfer vždy false | nulová | Záměr – služby jdou přes reservation_services |

---

## 6. SCHÉMA TOKU DAT (zjednodušené)

```
AddReservationDialog._onSave()
    │
    ├─► Kontrola tenantId (throw pokud null)
    ├─► Kontrola _selectedApartmentId
    ├─► Kontrola _dateRange
    ├─► Kontrola kolizí (newCheckIn, newCheckOut)
    │
    ├─► KROK 1: SupabaseService.client.from('reservations').insert(payload)
    │       payload = { tenant_id, apartment_id, start_date, end_date,
    │                   guest_name, guest_phone, reservation_source,
    │                   needs_transfer, guest_adults, guest_children,
    │                   arrival_time, departure_time, internal_note }
    │       → vrací nové id
    │
    └─► KROK 2: saveForReservation(reservationId, tenantId, _servicesState)
            → delete existing reservation_services
            → insert pro každou enabled službu:
              { tenant_id, reservation_id, apartment_service_id,
                charged_price, custom_note, payer_type }
```

---

*Report vygenerován automatickou analýzou kódu. Žádný kód nebyl změněn.*
