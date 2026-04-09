# Analýza připravenosti FalcoNest na požadavky Dommie (komunikace s hosty)

**Kontext:** Klientka Dommie spravuje apartmány a požaduje (1) automatické odesílání check-in/check-out zpráv před příjezdem/odjezdem a (2) kalendář rezervací s přímým odkazem na WhatsApp hostů.  
**Stack:** Flutter (Mobile/Web), Supabase (PostgreSQL, Auth, Edge Functions, Realtime).  
**Úkol:** Pouze analýza a návrh, bez implementace.

---

## 1. Požadavek: Automatické odesílání check-in / check-out zpráv před příjezdem/odjezdem

### 1.1 Současný stav (ověření v kódu a DB)

#### Databáze: tabulka pro šablony zpráv

- **Ano.** Tabulka `tenant_message_templates` existuje (migrace `20260231200000_tenant_message_templates.sql`).
- **Sloupce:**  
  `id`, `tenant_id`, `key`, `name`, `body`, `channel`, `language_code`, `trigger_context`, `order_index`, `created_at`, `deleted_at`.
- **Placeholdery:** Sloupec `body` je určen pro text s placeholdery. Komentář v DB explicitně uvádí:  
  `{guest_name}, {flight_number}, {address}, {keybox}, …`
- **Kanál:** `channel` má CHECK: `'whatsapp_link' | 'sms' | 'email'` (výchozí `whatsapp_link`).
- **Kontext:** `trigger_context` může být `transfer`, `check_in`, `check_out` – vhodné pro filtrování šablon podle typu události.

#### Služba pro merge proměnných

- **Ano.** `TemplatePlaceholderService` (`lib/features/communication/services/template_placeholder_service.dart`):
  - `replacePlaceholders(String templateBody, Map<String, String> values)` – nahradí `{klíč}` hodnotami z mapy.
  - `buildContextFromTask(WorkerTaskDetail detail, {reservation?, apartment?})` – sestaví mapu placeholderů z úkolu (host, adresa, keybox, flight_number, …).
  - `resolveGuestPhone(detail, reservation?)` – fallback chain pro telefon (task → client → reservation → parsing z poznámky).
- **Omezení:** Kontext se zatím sestavuje pouze z **WorkerTaskDetail** (úloha řidiče/uklízečky). Pro čistě „rezervační“ kontext (admin / automatizace bez úkolu) by bylo potřeba **nová metoda** typu `buildContextFromReservation(ReservationRow, {apartmentName, address, keybox})` a naplnění stejných klíčů (`guest_name`, `guest_phone`, `apartment_name`, `address`, `keybox`, …).

#### Otevření WhatsApp ve Flutteru

- **Ano.** V Worker flow (`transfer_task_screen.dart`):
  - Použit `url_launcher`: `launchUrl(url, mode: LaunchMode.externalApplication)`.
  - URL: `https://wa.me/$cleanedPhone?text=$encodedText`.
  - Telefon se očistí na samé číslice: `resolvedPhone.replaceAll(RegExp(r'[^\d]'), '')`.
  - Text šablony se merguje přes `TemplatePlaceholderService.buildContextFromTask` + `replacePlaceholders`, pak `Uri.encodeComponent(parsedText)`.
- **Chování:** Jedná se o **manuální** krok – řidič klikne na šablonu u úkolu a otevře se WhatsApp s předvyplněným textem. Žádné automatické odeslání zprávy hostovi.

**Shrnutí současného stavu:**  
Máme šablony s placeholdery, službu pro merge (zatím jen z úkolu), otevření WhatsApp z aplikace a připomínky pro **řidiče** (push „pošlete šablonu“). **Nemáme** automatické odeslání e-mailu/WhatsAppu hostovi v pevný čas (např. 2 dny před příjezdem).

---

### 1.2 Návrh řešení: plná automatizace (bez kliknutí)

Cíl: např. „2 dny před check-inem“ nebo „1 den před check-outem“ systém sám odešle hostovi e-mail nebo WhatsApp zprávu s textem ze šablony (po nahrazení placeholderů).

#### A) Kdy odeslat (trigger)

- **Doporučení:** **Supabase Edge Function** volaná z **pg_cron** v pevné časy (např. každé ráno 08:00 Europe/Prague).
- **Alternativa:** Database trigger po INSERT/UPDATE rezervace – možný, ale „2 dny před“ vyžaduje naplánovaný běh v čase, ne jen reakci na změnu dat. Trigger by musel pouze zapsat „úkol k odeslání“ do fronty a cron/worker by ji zpracoval. Čistší je tedy **cron → Edge Function**.
- **Existující infrastruktura:** V projektu už je:
  - `pg_cron` (4× denně pro template-reminders),
  - tabulka `cron_edge_config` (URL + anon key pro volání Edge Function),
  - funkce `invoke_template_reminders()` (volá `template-reminders`).
- **Návrh:** Přidat nový cron job (např. jednou denně 08:00) a novou Edge Function např. `send-checkin-checkout-messages`:
  - Načte rezervace se `start_date` / `end_date` v rozmezí „zítra + 2 dny“ (pro check-in) a „zítra + 1 den“ (pro check-out) – podle požadované logiky (2 dny před příjezdem / 1 den před odjezdem).
  - Pro každou rezervaci: načte šablonu podle `trigger_context` (check_in / check_out) a jazyka (např. z preference hosta nebo výchozí).
  - Sestaví text (merge placeholderů z rezervace + bytu: guest_name, guest_phone, apartment_name, address, keybox, …).
  - Zavolá externí službu pro odeslání (e-mail nebo WhatsApp API – viz níže).

#### B) E-mailová služba / WhatsApp API

- **E-mail:**  
  Integrace do Edge Function (Deno): např. **Resend**, **SendGrid** nebo **Postmark**.  
  Edge Function by měla mít nastavené API klíče (env) a volat REST API dané služby. Resend/SendGrid jsou běžně použitelné z Deno.
- **WhatsApp:**  
  Automatické odeslání z backendu vyžaduje **WhatsApp Business API**:
  - **Twilio API for WhatsApp** – jednoduchá integrace, platí se za zprávu.
  - **Meta WhatsApp Cloud API** – oficiální, vyžaduje schválení Business účtu a šablony zpráv (pro „session“ zprávy mimo 24h okno jsou šablony nutné).
  Pro „předvyplněný“ text (check-in instrukce) by se typicky použily **šablony schválené Meta** a Edge Function by volala Meta/Twilio API s názvem šablony a parametry (např. guest_name, keybox_code).
- **Poznámka:** Aktuálně máme v DB `channel = 'whatsapp_link'` – to odpovídá **deep linku** (wa.me), tedy otevření WhatsApp na zařízení uživatele. Skutečné **backend odeslání** WhatsApp zprávy je jiný kanál a vyžaduje výše uvedené API a případně úpravu modelu (např. `channel = 'whatsapp_api'` pro automatické odeslání).

#### C) Složitost implementace (odhad)

| Část | Náročnost | Poznámka |
|------|-----------|----------|
| Cron + volání nové Edge Function | **Low** | Vzor už existuje (template-reminders, cron_edge_config). |
| Edge Function: výběr rezervací (start_date/end_date, tenant) | **Low** | Jednoduchý Supabase dotaz, RLS s service_role. |
| Merge placeholderů na backendu (rezervace + byt) | **Low** | Logika z TemplatePlaceholderService převést do TS nebo volat shared logiku; případně jednoduchá kopie mapování v Edge Function. |
| Integrace e-mailu (Resend/SendGrid) | **Low–Medium** | REST API, env klíče, šablona těla z DB. |
| Integrace WhatsApp Business API (Twilio/Meta) | **Medium–High** | OAuth/API klíče, schválení šablon (Meta), testování, případně úprava šablon v DB na formát vyžadovaný API. |
| Výběr šablony podle trigger_context (check_in/check_out) a jazyka | **Low** | Dotaz do `tenant_message_templates`. |
| Audit / „už odesláno“ (aby se neposílalo 2×) | **Medium** | Nová tabulka např. `guest_message_sends (reservation_id, template_id, sent_at, channel)` nebo rozšíření rezervace o `checkin_message_sent_at` apod. |

**Celkový odhad:**  
- Pouze **e-mail (Resend/SendGrid)** a odeslání v pevný čas (cron + Edge Function): **Medium**.  
- **WhatsApp automatické odeslání** (Twilio/Meta): **Medium–High** (kvůli API a schvalování šablon).

---

## 2. Požadavek: Kalendář rezervací s přímým linkem na WhatsApp klientů

### 2.1 Ověření

#### Telefonní číslo v rezervaci

- **Ano.** Tabulka `reservations` má sloupec `guest_phone` (TEXT), přidaný v migraci `20250325_reservations_guest_phone_source_departure.sql`.
- **Formát:** V DB není CHECK ani validace – ukládá se to, co uživatel zadá. Ve Worker flow se před sestavením `wa.me` URL číslo očistí na samé číslice: `replaceAll(RegExp(r'[^\d]'), '')`, což funguje i s předvolbou (+420…). Pro konzistenci a spolehlivost wa.me je vhodné ukládat číslo **s předvolbou** (např. +420…) a v UI při generování URL stejně odstranit nečíselné znaky.

#### Zobrazení telefonu a WhatsApp v UI

- **Telefon:** V administraci se `guest_phone` zobrazuje:
  - V **Kanban kartě** rezervace (`_KanbanCardContent`): jako text s ikonou telefonu (`Icons.phone_outlined`), pokud je vyplněno.
  - V **timeline (Plachtě)** rezervace se zobrazuje jen jméno hosta, referenční číslo, počet hostů, transfer, interní poznámka – **telefon ani WhatsApp tam nejsou**.
  - V **listu** rezervací (`_ReservationCard`) se telefon nezobrazuje.
- **WhatsApp:** V celém admin rezervačním UI (**seznam, Kanban, timeline**) **není** ikona ani tlačítko pro otevření WhatsApp (wa.me s předvyplněným textem). To znamená, že tvrzení „kliknutím na kolonku WhatsApp hosta přesměrovat…“ v současné implementaci **splněno není** – data máme, ale žádné „WhatsApp“ tlačítko/link v kalendáři nebo v detailu rezervace není.

#### Kam přidat logiku (merge + url_launcher)

- **Místa v kódu:**
  1. **Kanban karta rezervace** (`_KanbanCardContent`, `admin_reservations_screen.dart`): Vedle zobrazení `guest_phone` přidat ikonu/tlačítko „WhatsApp“ (např. zelená ikona). Při kliknutí: sestavit text šablony (merge), vygenerovat `wa.me` URL, `launchUrl`.
  2. **Detail rezervace (edit dialog):** V `EditReservationDialog` / `admin_reservation_forms.dart` – v sekci kde se zobrazuje host (jméno, telefon) přidat tlačítko „Otevřít WhatsApp“. Stejná logika: merge + launch.
  3. **Timeline (Plachta):** V bloku rezervace (`_TimelineReservationBlock`) lze přidat malou ikonu WhatsApp (např. v rohu), pokud je `guest_phone` vyplněno – opět merge + launch.

- **Merge v Admin kontextu:**  
  `TemplatePlaceholderService` dnes umí pouze `buildContextFromTask(WorkerTaskDetail, …)`. Pro rezervaci bez úkolu je potřeba:
  - Buď **rozšířit** `TemplatePlaceholderService` o metodu např. `buildContextFromReservation(ReservationRow r, {String? apartmentName, String? address, String? keybox})`, která vrátí `Map<String, String>` se stejnými klíči (`guest_name`, `guest_phone`, `apartment_name`, `address`, `keybox`, …), nebo
  - Sestavit tuto mapu přímo v admin vrstvě (např. v `admin_reservations_screen.dart` nebo v malém helperu) z `ReservationRow` + načtených dat bytu (apartment name, address, keybox z `apartments`).  
  Pak: zvolit šablonu (např. výchozí nebo podle `trigger_context`: check_in/check_out), zavolat `TemplatePlaceholderService.replacePlaceholders(template.body, contextMap)`, očistit telefon, sestavit `https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(mergedText)}`, `launchUrl`.

- **Výběr šablony:** V admin UI při „Otevřít WhatsApp“ lze nabídnout dropdown šablon s `trigger_context` check_in / check_out (nebo jednu výchozí), načtených z `messageTemplatesAdminProvider` / `tenant_message_templates`.

### 2.2 Složitost

- **Low.**  
  - Přidat 1–2 místa v UI (Kanban karta + detail/dialog rezervace, příp. timeline) s ikonou WhatsApp.  
  - Zavolat existující `replacePlaceholders`, sestavit kontext z `ReservationRow` + byt (nová helper metoda nebo rozšíření `TemplatePlaceholderService`).  
  - Použít stávající `url_launcher` a stejné očištění telefonu jako ve Worker flow.  
  - Žádná změna DB ani Edge Function pro tento požadavek není nutná.

---

## 3. Shrnutí a doporučení

| Požadavek | Připravenost | Co chybí | Odhad složitosti |
|-----------|--------------|----------|-------------------|
| **Automatické odesílání check-in/check-out zpráv** | Částečně | Automatické odeslání **hostovi** (e-mail/WhatsApp API). Dnes existuje pouze připomínka **řidiči** (FCM). Šablony a placeholdery jsou připraveny; merge z rezervace (bez úkolu) je třeba doplnit na backendu. | **Medium** (e-mail) / **Medium–High** (WhatsApp API). |
| **Kalendář/rezervace s linkem na WhatsApp** | Data ano, UI ne | V admin UI chybí WhatsApp tlačítko/link u rezervací (Kanban, detail, timeline). Kontext pro merge z rezervace (místo z úkolu) je třeba sestavit (nová metoda nebo helper). | **Low.** |

**Doporučené další kroky:**

1. **Rychlý win (Dommie – „kliknout na WhatsApp u hosta“):**  
   Implementovat v admin rezervacích (Kanban + detail rezervace, příp. timeline) tlačítko/ikonu WhatsApp; rozšířit `TemplatePlaceholderService` (nebo admin helper) o sestavení mapy placeholderů z `ReservationRow` + byt; použít stávající `replacePlaceholders` a `url_launcher` ve stejném stylu jako v Worker flow. **Složitost: Low.**

2. **Automatizace check-in/check-out:**  
   Navrhnout novou Edge Function (např. `send-checkin-checkout-messages`) volanou z pg_cron (např. denně 08:00); v ní vybírat rezervace podle data příjezdu/odjezdu, načítat šablony podle `trigger_context`, mergovat placeholdery z rezervace a bytu; integrovat e-mail (Resend/SendGrid) a případně WhatsApp Business API (Twilio/Meta); zavést jednoduchou evidenci odeslaných zpráv, aby se neposílalo opakovaně. **Složitost: Medium (e-mail) až Medium–High (WhatsApp API).**

---

*Dokument vznikl analýzou kódu a migrací FalcoNest (březen 2026).*
