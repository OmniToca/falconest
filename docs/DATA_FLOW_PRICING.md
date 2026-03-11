# Tok dat: Cena a plátce služeb (Katalog → Byt → Rezervace → Úkol)

Tento dokument popisuje, jak se v systému FalcoNest dědí a zamykají **cena** a **plátce** (kdo platí: majitel vs. host) od globálního katalogu až po konkrétní úkol. Cílem je mít jasno v tom, co je kdy „zamražené“ a proč se při fakturaci musí číst z úkolu nebo rezervace, nikdy z aktuálního ceníku.

---

## Přehled řetězce

```
tenant_services  →  apartment_services  →  reservation_services  →  tasks.metadata
   (katalog)           (byt – override)        (rezervace – snapshot)    (úkol – finální pravda)
```

---

## KROK 1: `tenant_services` (Globální katalog)

- **Účel:** Centrální katalog služeb agentury (Úklid, Transfer, Check-in, …).
- **Klíčové sloupce:** `name`, `service_type`, `default_price`, `description`, …
- **Jak se tvoří základ:** Služba má výchozí cenu (`default_price`) a typ. Tato úroveň je **referenční** – sama o sobě se k konkrétnímu bytu ani rezervaci neváže.
- **Dědění:** Na další úrovni (`apartment_services`) lze cenu a popis přepsat pro konkrétní byt.

---

## KROK 2: `apartment_services` (Byt – přepis ceny a plátce)

- **Účel:** Pro každý byt definovat, které služby z katalogu se u něj nabízejí, za kolik a kdo platí.
- **Klíčové sloupce:** `apartment_id`, `service_id` (FK na `tenant_services`), `custom_price`, `payer_type` (owner | guest), `trigger_type`, …
- **Jak si apartmán může cenu upravit:** `custom_price` přepisuje `default_price` z katalogu. NULL = použít výchozí cenu z `tenant_services`.
- **Plátce:** `payer_type` určuje, zda službu platí **majitel** (faktura) nebo **host** (hotovost na místě).
- **Důležité:** Tato tabulka odráží **aktuální** stav bytu. Při přeřazení bytu jinému majiteli/klientovi mohou být záznamy nahrazeny nebo smazány. Pro historickou fakturaci se odtud **nesmí** brát cena/plátce u již dokončených úkolů.

---

## KROK 3: `reservation_services` (Rezervace – fixace dohodnutých podmínek)

- **Účel:** U konkrétní rezervace uložit, které služby host objednal a za jakých podmínek (cena a plátce **v okamžiku vytvoření/uložení rezervace**).
- **Klíčové sloupce:** `reservation_id`, `apartment_service_id` (FK na `apartment_services`), `charged_price`, `payer_type`, `custom_note`, `flight_number`, …
- **Co přesně se sem překopíruje:** Při ukládání rezervace (dialog „Služby a požadavky“) se pro každou zaškrtnutou službu zapíše:
  - **charged_price** – účtovaná cena za tuto službu u této rezervace (může přepsat výchozí z bytu).
  - **payer_type** – kdo platí u této rezervace (owner / guest); NULL = použít z `apartment_services`.
- **Proč to fixuje dohodnuté podmínky:** Řádek v `reservation_services` je **snapshot** – už se nemění podle toho, že později někdo změní ceník bytu nebo přiřadí byt jinému majiteli. Historická fakturace má číst odtud (nebo z úkolu), ne z `apartment_services`.

---

## KROK 4: `tasks.metadata` (Úkol – finální a nezměnitelná hodnota)

- **Účel:** U konkrétního úkolu uchovat cenu a případně částku k vybrání v okamžiku vzniku úkolu (nebo dokončení). Jedná se o **absolutní pravdu** pro reporty a fakturaci.
- **Klíčové klíče v JSONB `metadata`:**
  - **`service_price`** – cena služby k fakturaci (typicky u úklidu / služeb platících majitel). Nastavuje se při vytvoření úkolu (manuálně z formuláře nebo z rezervace).
  - **`amount_to_collect`** – částka k vybrání od hosta (hotovost) – např. transfer, check-in poplatek.  
    **BYZNYS PRAVIDLO:** Přítomnost `amount_to_collect` > 0 je v celém systému **automatickým ekvivalentem** pro „host platí hotovost“ (payer_type = guest). Mobilní UI i fakturace mohou v případě chybějícího explicitního `payer_type` inferovat plátce = guest z existence tohoto klíče. Starší data nemusí mít `payer_type` vyplněný – stačí `amount_to_collect`.
  - **`payer_type`** – explicitní plátce (owner | guest | client); pokud chybí, `amount_to_collect` > 0 implikuje guest.
- **Kdy a jak se to sem překopíruje:**
  - **Manuální vytvoření/úprava úkolu (Admin):** U úkolu vázaného na apartmán se zadaná cena zapisuje do `metadata['service_price']`. U externího úkolu s „Personál vybírá hotovost“ se zapisuje `metadata['amount_to_collect']`.
  - **Automatické generování úkolů z rezervace (scheduling):** Z `reservation_services` se do `metadata` kopírují např. `amount_to_collect` (transfer, check-in), `collection_breakdown`, `flight_number`, atd. Pro některé typy úkolů může být do metadat zapsána i ekvivalentní „cena“ (dle implementace v `admin_tasks_provider` / UI).
- **Proč je to finální a nezměnitelná hodnota:** Jakmile je úkol vytvořen a metadata nastavena, změna ceníku v katalogu nebo přeřazení bytu jinému majiteli **nesmí** změnit to, co se zobrazuje na faktuře za tento úkol. Fakturace a podklady pro fakturaci tedy musí v první řadě číst z `tasks.metadata` (service_price, amount_to_collect) a teprve při jejich absenci použít hodnoty z `reservation_services` (a nikdy ne přímo z `apartment_services` / aktuálního ceníku).

---

## Shrnutí pravidel pro fakturaci (Podklady pro fakturaci)

1. **Primárně** použít údaje z **úkolu**: `tasks.metadata.service_price`, `tasks.metadata.amount_to_collect`. To je hodnota „vypálená“ v okamžiku vzniku úkolu.
2. **Sekundárně** (když metadata nemají cenu) použít **rezervaci**: `reservation_services.charged_price` a `reservation_services.payer_type` pro danou rezervaci a službu. Mapování úkol → rezervace jde přes `tasks.reservation_id` a `tasks.service_id`; pokud kvůli přeřazení bytu už v `apartment_services` neexistuje odpovídající záznam, musí se použít fallback přímo z řádků `reservation_services` (bez závislosti na `apartment_services`).
3. **Nikdy** nebrat cenu ani plátce z **aktuálního** stavu `apartment_services` ani z ceníku klienta pro již dokončené úkoly – to by vedlo k „dynamickému přepočtu“ a přepisování historie při změně majitele bytu.

---

## Odkazy v kódu

- **Načtení ceny/plátce pro fakturaci:** `lib/features/admin/providers/finance_billing_provider.dart` (billingReportProvider, clientBillingProvider) – po opravě preferuje `task.metadata` a používá fallback z `reservation_services` bez závislosti na `apartment_services`.
- **Zápis do reservation_services:** `lib/features/admin/providers/reservation_services_repository.dart` (`saveForReservation`).
- **Zápis do tasks.metadata při vytvoření/úpravě úkolu:** `lib/features/admin/admin_tasks_screen.dart` (manuální úkol), `lib/features/admin/providers/admin_tasks_provider.dart` (generované úkoly z rezervace).
- **Schéma DB:** `supabase/migrations/20250318_three_tier_services.sql`, `20250321_add_payer_type_to_services.sql`.
