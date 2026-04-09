# FÁZE 6: Tlačítko na rezervační plachtě a indikátor odeslání – analýza a návrh

**Cíl:** Rychlý přístup k WhatsApp šablonám přímo z plachty a vizuální indikátor „zpráva již byla připravena“, aby recepční neposílali duplicity a nemuseli dotazovat audit_logs.

---

## 1. Tlačítko na plachtě (Timeline)

### 1.1 Kde je blok rezervace

- **Widget:** `_ReservationTimelineBlock` v `lib/features/admin/admin_reservations_screen.dart` (řádky cca 1245–1386).
- **Parametry:** `reservation`, `startDate`, `dayWidth`, `rowHeight`, `apartmentIndexById`, `onTap` (otevře edit dialog).
- Blok je **Positioned** v mřížce; obsah je **InkWell** → **Container** s **Column**: první řádek = jméno hosta + ref. číslo, druhý řádek (pokud `width > 120`) = 👥 počet + ikony transfer/poznámka.

### 1.2 Kam umístit ikonu WhatsAppu

**Doporučení: pravý horní roh bloku, malá zelená ikona.**

- **Varianta A (doporučená):** V prvním řádku **Row** přidat na konec (za `referenceNumber`) **IconButton** nebo **GestureDetector** s ikonou `Icons.chat` (zelená `Colors.green.shade700`), velikost cca 20–22 px. Kliknutí **nesmí** spustit `onTap` (edit) – v Flutteru vnitřní widget (IconButton) událost spotřebuje, takže stačí nepřidávat edit do onPressed ikony.
- **Varianta B:** Druhý řádek vedle ikon transfer/poznámka přidat ikonu chatu (konzistentní s Kanbanem). Nevýhoda: při úzkém bloku (`width <= 120`) se druhý řádek nezobrazuje, takže by ikona zmizela.
- **Závěr:** Ikona v **pravé části prvního řádku** (nebo jako překryv v pravém horním rohu bloku), vždy viditelná. Např. `Row(children: [ Expanded(child: Text(guestName)...), if (refNum) ..., IconButton(icon: Icon(Icons.chat, size: 20, color: Colors.green.shade700), onPressed: onWhatsAppTap, padding: EdgeInsets.zero, constraints: BoxConstraints(minWidth: 32, minHeight: 32)) ])`.

### 1.3 Předání callbacku a otevření bottom sheetu

- **ReservationTimeline** (ř. 733) dnes má: `onReservationTap`, `onEmptyCellTap`. Přidat: **`ValueChanged<ReservationRow>? onReservationWhatsApp`**.
- **Kde se timeline buduje:** V `_AdminReservationsScreenState.build` (ř. cca 179) se volá `ReservationTimeline(..., onReservationTap: (r) => _showEditDialog(context, ref, r), onEmptyCellTap: ...)`. Přidat **`onReservationWhatsApp: (r) => _openWhatsAppForReservation(context, ref, r)`**.
- **Nová metoda v obrazovce:** `_openWhatsAppForReservation(BuildContext context, WidgetRef ref, ReservationRow r)`:
  - Načte byt: `apartmentsById[r.apartmentId]` z `ref.read(apartmentsFullListProvider).valueOrNull` (nebo předat mapu z buildu).
  - Sestaví `ApartmentPlaceholderContext` z bytu (name, address, keybox, ownerNotes).
  - Zavolá `MessageTemplateSelectorBottomSheet.show(context, ref, MessageTemplateSelectorContext.fromReservation(r, apartment: aptCtx))`.
- **Řetěz předání:**  
  `ReservationTimeline` → **`_ReservationTimelineGrid`** (ř. 969): přidat parametr **`ValueChanged<ReservationRow>? onReservationWhatsApp`**.  
  Při mapování rezervací na bloky (ř. 1080) předat **`onWhatsAppTap: onReservationWhatsApp != null ? () => onReservationWhatsApp!(r) : null`**.  
  **`_ReservationTimelineBlock`**: přidat **`VoidCallback? onWhatsAppTap`**; v buildu v prvním Row přidat malou ikonu, která při `onWhatsAppTap != null` volá `onWhatsAppTap()` (bez volání `onTap`).

Apartment pro kontext už v buildu timeline máme (`apartmentsAsync.valueOrNull`), takže v `_openWhatsAppForReservation` můžeme předat buď celý seznam bytů, nebo předem sestavenou mapu `apartmentId → ApartmentRow` z rodiče (aby se nevolal provider znovu). Jednoduché: v metodě `_openWhatsAppForReservation` načíst `ref.read(apartmentsFullListProvider).valueOrNull`, z toho sestavit mapu a vybrat byt pro `r.apartmentId`.

---

## 2. Indikátor odeslání (zamezení duplicitám)

### 2.1 Proč ne dotazovat audit_logs

- Při každém renderu plachty/Kanbanu bychom museli pro každou rezervaci (nebo hromadně) číst `audit_logs` a hledat poslední `WHATSAPP_LINK_OPENED` s `record_id` = reservation.id. Tabulka audit_logs roste, dotazy by byly pomalé a zatěžovaly DB i při 1000 uživatelích.
- **Řešení:** Denormalizace – na rezervaci uložit „naposledy odeslaný kontext“ a čas. Načítání rezervací už stejně probíhá (stream/select); stačí do SELECT přidat dva sloupce. Žádný další dotaz.

### 2.2 Návrh migrace (Supabase)

**Nový soubor:** např. `supabase/migrations/20260322120000_reservations_last_communication.sql`

```sql
-- Indikátor poslední připravené WhatsApp zprávy (denormalizace z audit logu).
-- PROČ: Aby UI mohlo zobrazit „Check-in odeslán“ bez dotazování audit_logs.
ALTER TABLE reservations
  ADD COLUMN IF NOT EXISTS last_communication_template_context text,
  ADD COLUMN IF NOT EXISTS last_communication_at timestamptz;

COMMENT ON COLUMN reservations.last_communication_template_context IS 'trigger_context použité šablony (např. check_in, transfer_in). NULL = nebylo odesláno.';
COMMENT ON COLUMN reservations.last_communication_at IS 'Čas posledního vygenerování WhatsApp odkazu (úmysl odeslání).';
```

- **Typ:** `text` (nullable) pro kontext, `timestamptz` (nullable) pro čas. Žádný FK, žádný trigger – pouze sloupce.

### 2.3 Kdy a jak zapisovat

- **Kde:** V **`MessageTemplateSelectorBottomSheet._onTemplateTap`**, hned po úspěšném zápisu do Audit logu (nebo souběžně s ním), **před** `launchUrl`.
- **Podmínka:** Kontext musí být **`ReservationTemplateContext`** – jen u rezervace má smysl ukládat na rezervaci. U Worker úkolu / Admin úkolu tyto sloupce na rezervaci neměníme.
- **Co uložit:**  
  - `last_communication_template_context` = `template.triggerContext` (nebo prázdný string; v DB ukládat např. `null` pokud je prázdný).  
  - `last_communication_at` = `DateTime.now().toUtc()`.
- **Jak:** Asynchronní **UPDATE** rezervace v Supabase (podle `reservation.id`). Aby neblokoval UX: **nečekat** na dokončení před `launchUrl`. Např. `unawaited(_updateReservationLastCommunication(reservationId, triggerContext))` nebo `Future.microtask(() => _updateReservationLastCommunication(...))`. Při chybě sítě pouze logovat (debugPrint / Sentry), neblokovat uživatele.
- **Reservation ID v kontextu:** Dnes **`ReservationTemplateContext`** drží `ReservationRow reservation` – má tedy `reservation.id`. V bottom sheetu ale máme pouze `MessageTemplateSelectorContext` (sealed). Musíme z kontextu získat `reservationId` jen když je to `ReservationTemplateContext`. Přidat na kontext např. getter **`String? get reservationId`**, který u `ReservationTemplateContext` vrací `reservation.id`, u ostatních `null`. Pak v `_onTemplateTap` zkontrolovat `final reservationId = templateContext.reservationId; if (reservationId != null) { unawaited(updateReservationLastCommunication(reservationId, template.triggerContext)); }`.

### 2.4 Aktualizace dat po zápisu

- Po UPDATE rezervace v Supabase **Realtime stream** (který už živí `adminReservationsProvider`) sám pošle nová data – pokud má stream předplatné na `reservations`, uvidí změnu a UI se překreslí bez ruční invalidace.
- Pokud by stream nebyl nakonfigurovaný na tyto sloupce, stejně při dalším načtení (refresh, přepnutí záložky) se načtou nové sloupce – u standardního `.select()` bez výčtu sloupců se načtou všechny. Takže po migraci stačí rozšířit model a SELECT (viz níže).

### 2.5 Rozšíření modelu a načítání

- **ReservationRow** (`admin_reservations_provider.dart` / stejný soubor kde je definice): přidat pole **`String? lastCommunicationTemplateContext`**, **`DateTime? lastCommunicationAt`**.
- V **`ReservationRow.fromJson`** číst `raw['last_communication_template_context']` a `raw['last_communication_at']` (parsovat datum jako obvykle).
- **Načítání:** Hlavní zdroj rezervací je **stream** z `AdminReservationsRepository.watchReservationsRaw` – volá **`.select()`** bez argumentů, tedy načte **všechny sloupce** včetně nových. Stačí rozšířit model; explicitní SELECT se používá v **`reservationsForProfileProvider`** a **`reservationsForApartmentProvider`** a **`clientReservationsProvider`** – do jejich řetězců **`.select('...')`** doplnit **`last_communication_template_context, last_communication_at`**, aby i tyto providery vracely data pro indikátor.

---

## 3. Zobrazení indikátoru v UI

### 3.1 Kanban karta

- V **`_KanbanCardContent`** (nebo tam, kde se vykresluje řádek s telefonem a ikonou WhatsApp) přidat **malý indikátor**, pokud `reservation.lastCommunicationAt != null`:
  - Např. malá ikona podle `lastCommunicationTemplateContext` (check_in → klíč, check_out → klíč jiná barva, transfer_in/out → auto, obecné → bublina) a tooltip např. „Check-in zpráva připravena 18. 3. 2026 14:32“.
  - Ikony a barvy konzistentní s **TaskVisuals** (getIcon, getBackgroundColor pro daný `taskType` = kontext), aby recepční na první pohled viděli typ.
- Umístění: např. vedle stávající zelené ikony WhatsApp (tlačítka pro odeslání), nebo pod telefonem jako druhý řádek „Poslední zpráva: Check-in, 18. 3. 14:32“.

### 3.2 Blok na plachtě (Timeline)

- V **`_ReservationTimelineBlock`** přidat **malou ikonu** (např. „✓“ nebo stejná ikona jako kontext), pokud `reservation.lastCommunicationAt != null`, např. v druhém řádku vedle 👥/transfer/poznámka, nebo jako jemný badge v rohu. Tooltip na hover (na webu) s datem a typem šablony.
- Aby blok nebyl přeplácaný: jedna malá ikona (např. `Icons.check_circle` zelená, nebo ikona z TaskVisuals podle `lastCommunicationTemplateContext`) s tooltipem.

### 3.3 Výkon

- **Žádné další dotazy:** Data přicházejí v již načtených rezervacích (stream / stávající SELECT). Na plachtě i Kanbanu jen čteme `reservation.lastCommunicationAt` a `reservation.lastCommunicationTemplateContext` – žádné volání audit_logs, žádné N+1.

---

## 4. Konkrétní kroky implementace (bez kódu – checklist)

1. **Migrace**  
   - Přidat migraci `20260322120000_reservations_last_communication.sql` s `ALTER TABLE reservations ADD COLUMN last_communication_template_context text, ADD COLUMN last_communication_at timestamptz` a komentáře.

2. **Model a načítání**  
   - V `ReservationRow` přidat `lastCommunicationTemplateContext` a `lastCommunicationAt`, v `fromJson` je naplnit.  
   - V každém `.select(...)` rezervací v projektu doplnit do výčtu sloupců `last_communication_template_context, last_communication_at` (včetně streamu, pokud by byl s explicitním selectem – aktuálně stream používá `.select()` bez arg, takže nové sloupce přijde sám).

3. **Kontext a zápis z bottom sheetu**  
   - Na **`MessageTemplateSelectorContext`** (nebo jen na `ReservationTemplateContext`) přidat getter **`String? get reservationId`**.  
   - V **`MessageTemplateSelectorBottomSheet._onTemplateTap`** po zápisu audit logu: pokud `templateContext.reservationId != null`, zavolat **neblokující** update rezervace (např. služba `ReservationRepository.updateLastCommunication(reservationId, triggerContext)` nebo přímo Supabase update) s `last_communication_template_context` a `last_communication_at = now()`. Volat bez await (nebo v microtask) tak, aby `launchUrl` a zavření sheetu proběhly hned.

4. **Timeline – tlačítko WhatsApp**  
   - Do **`ReservationTimeline`** přidat **`ValueChanged<ReservationRow>? onReservationWhatsApp`**.  
   - Do **`_ReservationTimelineGrid`** přidat **`onReservationWhatsApp`** a předat ho do každého **`_ReservationTimelineBlock`** jako **`onWhatsAppTap`**.  
   - V **`_ReservationTimelineBlock`** přidat v prvním řádku (nebo v rohu) malou ikonu WhatsApp; při kliknutí volat **`onWhatsAppTap`**.  
   - V obrazovce rezervací v místě, kde se vytváří `ReservationTimeline`, předat **`onReservationWhatsApp: (r) => _openWhatsAppForReservation(context, ref, r)`** a implementovat **`_openWhatsAppForReservation`** (načíst byt, sestavit kontext, `MessageTemplateSelectorBottomSheet.show(...)`).

5. **Indikátor na Kanbanu**  
   - V **`_KanbanCardContent`** podle `reservation.lastCommunicationAt` a `reservation.lastCommunicationTemplateContext` zobrazit malou ikonu + volitelný tooltip s datem/typem.

6. **Indikátor na plachtě**  
   - V **`_ReservationTimelineBlock`** podle `reservation.lastCommunicationAt` (a volitelně `lastCommunicationTemplateContext`) zobrazit malý vizuál (ikona / badge), s tooltipem na webu.

Tím bude plachta i Kanban bez dodatečných dotazů na audit_logs, s rychlým přístupem k WhatsApp z plachty a s jasným indikátorem „zpráva již byla připravena“ pro prevenci duplicit.
