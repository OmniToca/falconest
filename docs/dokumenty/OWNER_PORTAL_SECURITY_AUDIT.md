# Bezpečnostní audit (Rentgen) – Klientská zóna (Owner Portal)

**Datum auditu:** 2026-03  
**Rozsah:** `lib/features/owner/` a související providery  
**Cíl:** Odhalit potenciální únik dat mezi majiteli (data leak).

---

## Shrnutí

| Sekce | Stav | Poznámka |
|-------|------|----------|
| 1. Moje apartmány | ✅ BEZPEČNÉ | Dvoukrokový dotaz přes `apartment_owners` + `inFilter('id', apartmentIds)` |
| 2. Rezervace a kalendář | ❌ **ÚNIK DAT** | Žádný filtr na `apartment_id`; závislost pouze na RLS |
| 3. Úkoly a údržba | ✅ BEZPEČNÉ | Explicitní `.inFilter('apartment_id', ownedApartmentIds)` |
| 4. Vyúčtování a reporty | ✅ BEZPEČNÉ | Filtrace přes `client_id` odvozená z `profile_id` + `tenant_id` |
| Detail apartmánu | ✅ BEZPEČNÉ | Kontrola `ownedIds.contains(apartmentId)` před dotazem |
| Služby bytu (options) | ⚠️ RIZIKO | Chybí ověření vlastnictví bytu před načtením dat |

---

## 1. MOJE APARTMÁNY

**Soubor:** `lib/features/owner/providers/owner_apartments_provider.dart`

### [BEZPEČNÉ]

- **Krok 1:** Dotaz na `apartment_owners`:  
  `owner_id = profileId` (aktuální uživatel), `deleted_at IS NULL`, výběr `apartment_id`.  
  Získá se pouze seznam ID bytů, které má majitel přiřazené v `apartment_owners`.
- **Krok 2:** Dotaz na `apartments`:  
  `.inFilter('id', apartmentIds)` + `deleted_at IS NULL`.  
  Načtou se jen tyto byty (včetně vnořených `tasks`).

Žádný jiný dotaz v této sekci nečte seznam bytů majitele bez tohoto omezení.  
**Závěr:** Majitel vidí pouze byty z `apartment_owners`. Obrana v hloubce je dodržena.

---

## 2. REZERVACE A PLÁNOVACÍ KALENDÁŘ

### 2.1 Rezervace – načtení seznamu

**Soubor:** `lib/features/owner/providers/owner_reservations_provider.dart`  
**Řádky:** 56–66

### [ÚNIK DAT]

Dotaz na rezervace vypadá takto:

```dart
final response = await SupabaseService.client
    .from('reservations')
    .select(
      'id, apartment_id, start_date, end_date, ...',
      'apartments(name)',
    )
    .isFilter('deleted_at', null)
    .order('start_date', ascending: true);
```

- **Chybí jakýkoli filtr na `apartment_id`.**  
  V kódu není `.inFilter('apartment_id', ownerApartmentIds)` ani ekvivalent.
- Komentář v kódu uvádí: *„RLS na backendu zajistí, že majitel vidí jen rezervace u bytů z apartment_owners.“*

**Proč to vede k úniku:**

- Na tabulce `reservations` existují dvě SELECT politiky:
  1. **`reservations_select`** (migrace 20250306):  
     `USING (is_super_admin() OR EXISTS (apartments WHERE apartment_id = reservations.apartment_id AND tenant_id = my_tenant_id()))`.  
     Pro majitele (property_owner) je `my_tenant_id()` = tenant agentury. Tato politika tedy povolí **všechny rezervace tenantu** (celé agentury).
  2. **`reservations_property_owner_select`** (migrace 20260223):  
     Omezuje jen na rezervace u bytů z `apartment_owners` pro daného majitele.

- V PostgreSQL platí, že pokud existuje více politik pro SELECT, řádek je viditelný, pokud **alespoň jedna** politika povolí přístup.  
  U přihlášeného majitele tedy politika 1 povolí celý tenant → majitel vidí **všechny rezervace agentury**, ne jen své byty.

**Doporučení:**

1. **Aplikace:** V `owner_reservations_provider.dart` před dotazem na `reservations` načíst seznam ID vlastněných bytů (např. z `ownerApartmentsProvider`) a přidat **`.inFilter('apartment_id', ownerApartmentIds)`**.
2. **RLS:** Upravit `reservations_select` tak, aby se na role `property_owner` vůbec nepoužívala (např. podmínka typu „pouze pokud aktuální uživatel není property_owner“), tak aby u majitele platila jen `reservations_property_owner_select`.

---

### 2.2 Plánovací kalendář (úkoly pro kalendář)

**Soubor:** `lib/features/owner/providers/owner_planning_calendar_provider.dart`

### [BEZPEČNÉ]

- Načtou se `ownedApartmentIds` z `ownerApartmentsProvider`.
- Dotaz na `tasks`:  
  **`.inFilter('apartment_id', ownedApartmentIds)`** + další filtry (časové okno, `deleted_at`, `invoiced_at`).
- Rezervace se v tomto provideru přímo nečtou; kalendář zobrazuje úkoly, které jsou správně omezeny na byty majitele.

---

## 3. ÚKOLY A ÚDRŽBA

**Soubor:** `lib/features/owner/providers/owner_tasks_provider.dart`

### [BEZPEČNÉ]

- `ownedApartmentIds` z `ownerApartmentsProvider`.
- Dotaz na `tasks`:  
  **`.inFilter('apartment_id', ownedApartmentIds)`**, dále `deleted_at`, `invoiced_at`, řazení.
- Žádný dotaz na úkoly bez tohoto omezení v rámci owner portálu zde není.

---

## 4. VYÚČTOVÁNÍ A REPORTY

**Soubor:** `lib/features/owner/providers/owner_billing_provider.dart`

### [BEZPEČNÉ]

- **Krok 1:** Z `clients` se načtou záznamy kde `profile_id = profileId` a `tenant_id = tenantId` (aktuální uživatel a jeho tenant). Získá se seznam `client_id` tohoto majitele.
- **Krok 2:** Z `billing_snapshots` se načtou pouze záznamy s **`.inFilter('client_id', clientIds)`**.

Fakturační data jsou tedy omezena na klienta (majitele) přihlášeného v aplikaci.

---

## 5. DETAIL APARTMÁNU

**Soubor:** `lib/features/owner/providers/owner_apartment_detail_provider.dart`

### [BEZPEČNÉ]

- Provider je volán s konkrétním `apartmentId` (např. z cesty `/owner/apartment/:id`).
- **Před jakýmkoli dotazem:** načte se seznam vlastněných bytů z `ownerApartmentsProvider` a ověří se **`if (!ownedIds.contains(apartmentId)) return null`**.
- Teprve potom se volá dotaz na `apartments` s `.eq('id', apartmentId)`.

I při zmanipulovaném ID v URL tedy nedojde k vrácení detailu cizího bytu.

---

## 6. SLUŽBY BYTU (options pro rezervaci)

**Soubor:** `lib/features/owner/providers/owner_apartment_services_provider.dart`

### [RIZIKO – chybí ověření vlastnictví]

- Provider bere `apartmentId` jako parametr a:
  - načte z `apartments` `tenant_id` pro toto `apartment_id`,
  - pak načte `tenant_services` a `apartment_services` pro tento byt.
- **Neověřuje se**, zda `apartmentId` patří aktuálně přihlášenému majiteli (např. zda je v seznamu z `ownerApartmentsProvider`).

V typickém toku volá tento provider pouze `owner_reservations_screen.dart` s bytem vybraným z dropdownu naplněného z vlastněných bytů, takže v běžném použití by nemělo dojít k úniku. Pokud by však někdo předal jiné `apartmentId` (např. úprava stavu, deep link, budoucí API), provider by vrátil služby cizího bytu.

**Doporučení:** Na začátku provideru ověřit, že `apartmentId` je v seznamu vlastněných bytů (např. z `ownerApartmentsProvider`). Pokud není, vrátit prázdný seznam (nebo ekvivalent „bez přístupu“).

---

## 7. PŘÍMÉ VOLÁNÍ SUPABASE V OWNER OBLASTI

V `owner_reservations_screen.dart` jsou kromě providerů i přímé volání Supabase:

- **Řádky 530–535:** `apartments` – výběr `tenant_id` pro konkrétní `_selectedApartmentId` (před insertem/update rezervace).  
  `_selectedApartmentId` pochází z UI (dropdown); bez ověření vlastnictví v kódu by teoreticky šlo poslat cizí byt – záleží výhradně na tom, že dropdown je naplněn jen vlastněnými byty. Pro obranu v hloubce by bylo vhodné před zápisem ověřit, že `_selectedApartmentId` je v seznamu z `ownerApartmentsProvider`.
- **Řádky 600, 605:** `reservations` – update/insert konkrétní rezervace (podle `reservationId` resp. nový záznam).  
  Omezení přístupu závisí na RLS a na tom, že rezervace byla původně načtena v kontextu majitele (což je aktuálně právě kvůli chybějícímu filtru v provideru problematické – viz sekce 2.1).
- **Řádky 686–691:** `apartments` – opět pouze `tenant_id` pro dané `apartmentId` v kontextu editace rezervace.  
  Stejná poznámka jako u 530–535: ideálně ověřit vlastnictví bytu.

Žádné z těchto volání samo o sobě nenačítá „všechny rezervace agentury“; hlavní únik je v **`owner_reservations_provider.dart`** (žádný filtr na `apartment_id`).

---

## 8. SOUHRN NÁLEZŮ A DOPORUČENÍ

| # | Soubor | Nález | Doporučená úprava |
|---|--------|-------|-------------------|
| 1 | `owner_reservations_provider.dart` | **ÚNIK DAT** – žádný filtr na byty majitele | Před dotazem na `reservations` načíst ID vlastněných bytů (z `ownerApartmentsProvider`) a přidat `.inFilter('apartment_id', ownerApartmentIds)`. |
| 2 | RLS `reservations_select` | Majitel má stejný `my_tenant_id()` jako agentura → vidí všechny rezervace tenantu | Upravit politiku tak, aby pro roli `property_owner` neplatila (nebo aby u ní platila jen `reservations_property_owner_select`). |
| 3 | `owner_apartment_services_provider.dart` | **RIZIKO** – neověřuje vlastnictví bytu | Na začátku ověřit, že `apartmentId` je v seznamu vlastněných bytů; jinak vrátit prázdný seznam. |
| 4 | `owner_reservations_screen.dart` (insert/update) | Volitelné posílení | Před zápisem rezervace ověřit, že `_selectedApartmentId` je v seznamu vlastněných bytů. |

---

## Závěr

- **Kritický problém:** V záložce „Rezervace“ v Klientské zóně dochází k **úniku dat** – zobrazují se rezervace celé agentury. Příčina je dvojí:  
  1) v aplikaci chybí filtr na `apartment_id` v `owner_reservations_provider.dart`,  
  2) na DB vrstvě politika `reservations_select` povoluje majiteli (díky `my_tenant_id()`) přístup ke všem rezervacím tenantu.
- Ostatní audité sekce (Moje apartmány, Úkoly, Plánovací kalendář, Vyúčtování, Detail apartmánu) jsou v aktuálním kódu nastavené bezpečně nebo s jasně popsaným mírným rizikem (služby bytu + doporučení k ověření vlastnictví a k úpravě RLS).

Tento dokument slouží jako podklad pro návrh konkrétních úprav kódu a RLS (bez provedení změn v této fázi).
