# FalcoNest – stav projektu (audit Komunikace, Automatizace, Úkoly offline)

**Datum auditu:** 2025-03-18  
**Zaměření:** Twilio SMS, Automatizace (CRON / mozek / čekárna / dispečink), Správa úkolů offline-first, pravidla 1–6.

---

## 1. 🟢 HOTOVO A IMPLEMENTOVÁNO

### Komunikace (šablony, WhatsApp z klienta, SMS metrika)

- [x] **Šablony zpráv** – UI (`template_editor_dialog`, seznam šablon), CRUD přes Supabase, `tenant_message_templates`, RLS podle tenanta.
- [x] **WhatsApp z aplikace** – `WhatsAppSenderService` (placeholdery, `wa.me`, audit log, aktualizace `last_communication_*`) – **ne Twilio API z mobilu**, ale otevření odkazu v systému.
- [x] **SMS segment counter** – `SmsCounterUtils` + `SmsCounterInfo` / `SmsTextField` (`lib/core/utils/sms_counter_utils.dart`, `lib/core/widgets/sms_counter_text_field.dart`), texty přes `communication.sms_counter_*` (cs/en/es).
- [x] **i18n u komunikace** – šablony a snackbary převážně přes `.tr()`; viz sekce varování pro výjimky.

### Automatizace (DB, Edge, Admin UI)

- [x] **Schéma** – `automation_rules`, `automation_message_queue`, `tenant_message_log`, `tenant_usage_monthly`, enumy kanálů/statusů, RLS na `tenant_id` (`20260320090000_automation_engine_base.sql`).
- [x] **Mozek (enqueue)** – Edge Function `automation-enqueue` – pravidla, triggery, quiet hours, idempotence, řazení do fronty.
- [x] **Dispečink (odesílání)** – Edge Function `automation-dispatch` – Twilio **SMS** a **WhatsApp** (REST), fallback WA→SMS, zápis logu, inkrement `tenant_usage_monthly`, stržení kreditů peněženky (logika v souboru).
- [x] **Admin UI** – `AdminAutomationsScreen`: záložky Pravidla / Čekárna / Historie; CRUD pravidel (včetně editace), zrušení fronty, úprava textu payloadu ve frontě, seed výchozích pravidel.
- [x] **FCM – denní souhrn** – `daily-task-summary` – lokální klíče `title_loc_key` / `body_loc_key` + `Europe/Madrid` pro hranice dne; nativní `strings.xml` / `Localizable.strings` (cs, es, default en na Androidu).
- [x] **FCM – template reminders** – `template-reminders` + `pg_cron` konfigurace v migraci (`cron_edge_config`, joby) – **obsah notifikace viz 🚨**.

### Úkoly a offline-first

- [x] **Drift + fronta mutací** – `DriftMutationQueueService` (INSERT/UPDATE/DELETE + `OFFLINE_ISSUE_TASK`, hotovost, fotky úkolů…).
- [x] **Hlášení závady offline** – při síťové chybě enqueue `OFFLINE_ISSUE_TASK` → `processOfflineIssueTask` volá Edge **`process-issue-ai`** (`invoke`), nikoli přímý INSERT do `tasks` z online větve.
- [x] **Modely úkolů** – `tenant_id` v `TaskModel` / mapách (`task_model.dart` atd.).
- [x] **Riverpod** – providery pro automatizaci (`automation_rules_provider`, `automation_queue_provider`, `automation_log_provider`) – čtení přes `safeFrom` + tenant z auth.

### Pravidla (kontrola)

| Pravidlo | Stav (stručně) |
|----------|----------------|
| Additive | Nové soubory; jádrové engine soubory bez nutnosti mazání. |
| České komentáře | Ano u nových utilit/widgetů a většiny offline/automation Dart kódu. |
| i18n ve Flutter UI | Silně dodrženo v admin/communication; výjimky v 🚨. |
| Multi-tenant | DB RLS + `SupabaseService.safeFrom` / `safeInsertPayload` v app repozitářích. |
| Offline-first | Drift fronta, `network_sync_watcher`, procesory pro issue/fotky. |
| Riverpod / vrstvy | Providery + repositories pro automatizaci a úkoly. |

---

## 2. 🟡 ROZPRACOVÁNO NEBO CHYBÍ NAPOJENÍ

- [ ] **SMS counter v produkčních formulářích** – utilita + widget existují, ale **nejsou** pověšeny pod šablony SMS / editor textu ve frontě (uživatel zatím nevidí počítadlo „v provozu“ všude, kde píše SMS).
- [ ] **Cron pro `automation-enqueue` / `automation-dispatch`** – v repo **není** nalezena migrace `pg_cron` pro tyto dvě funkce (na rozdíl od `template-reminders`). Nasazení je pravděpodobně **manuální** (Dashboard Cron / externí scheduler) – riziko, že „mozek“ nebo „dispečink“ neběží, dokud není nastaveno.
- [ ] **Čekárna = úprava + čekání na workera** – UI umí **editovat** `editable_payload` a **zrušit** položku; **okamžité ruční odeslání SMS** z UI (mimo plán `scheduled_for`) **není** – odeslání dělá Edge `automation-dispatch` podle fronty.
- [ ] **E-mailový kanál v automatizaci** – `sendViaSendGridEmail` v `automation-dispatch` je **zamockované** (skutečné `fetch` zakomentované, `SIMULATE_SENDGRID_FAILURE`); předmět zprávy v kódu natvrdo česky v komentáři/mocku.
- [ ] **`process-issue-ai`** – **napojeno** z offline fronty (`DriftMutationQueueService` → `processOfflineIssueTask`). Online přímé volání z `issue_reporter_dialog` **není** – při úspěšné síti jde insert do `tasks` přímo (bez AI). To je záměr podle flow (AI jen přes EF při offline queue).
- [ ] **WhatsApp Business API (Twilio) vs. klientský WhatsApp** – v automatizaci jde o **Twilio** kanál; v aplikaci pro řidiče/admina jde o **wa.me** – dva paralelní světy, ne jednotná „Business API“ vrstva v appce.

---

## 3. 🔴 CHYBÍ A JE TŘEBA VYVINOUT (další sprinty)

### Webhooky Twilio (doručení / stavy)

- [ ] **Příjem statusů** (delivered, failed, undelivered…) z Twilio zpět do DB – aktuálně `tenant_message_log.status` a `external_api_id` plní dispatch po odeslání; **chybí** veřejný endpoint (Edge Function) pro Twilio status callback + ověření podpisu / tenant scope.
- [ ] **Sladění s `tenant_message_log`** – aktualizace řádků po webhooku (ne jen „sent“ při odeslání).

### WhatsApp Business API (architektura)

- [ ] **Jednotná strategie** – Twilio WhatsApp v `automation-dispatch` vs. `wa.me` v appce; dokumentace rozhraní, limity, šablony vs. session zprávy.
- [ ] **Konfigurace na tenant** – `From` / schválené šablony / opt-in hosta (připravit DB + UI později).

### E-maily (Resend)

- [ ] **Nahrazení / doplnění SendGrid** – požadavek na **Resend**; v kódu je SendGrid placeholder – **žádná** Resend integrace.
- [ ] **i18n předmětů a šablon** – žádné hardcoded předměty v češtině v produkční cestě.

### Ochrana limitů a spotřeby (SMS / kredit)

- [x] **Částečně hotovo** – `tenant_usage_monthly.sent_count` (per channel, per billing month), `deduct_wallet_credits` / `tenant_wallets` pro kredity v peněžence.
- [ ] **Segmenty SMS** – agregace je **počet odeslaných zpráv** / kanál, ne **segmenty GSM/UCS-2** – pro přesné FÚčtování SMS od operátora je třeba doplnit (sloupec nebo výpočet z délky těla).
- [ ] **Tvrdé limity** – policy „tenant nesmí překročit N SMS měsíčně“ není v tomto auditu ověřena jako DB constraint nebo RPC.

---

## 4. 🚨 PORUŠENÍ / RIZIKA PRAVIDEL (Varování)

### i18n (hardcoded nebo mimo JSON)

- [ ] **Edge `template-reminders/index.ts`** – FCM `title` / `body` **natvrdo česky** (např. `📱 Čas na zprávu: ${guestName}`, `getNotificationBody` česky) – **porušení** záměru i18n pro push; **není** v souladu s modelem `daily-task-summary` (loc keys).
- [ ] **Edge funkce – JSON odpovědi a chybové hlášky** – české stringy v `Response` u `daily-task-summary`, `automation-dispatch`, `process-issue-ai` atd. – **ne UI aplikace**, ale konzistence s mezinárodním provozem.
- [ ] **`automation-dispatch`** – předmět SendGrid v mocku: `"FalcoNest automatická zpráva"` (v kódu u zakomentovaného volání).
- [ ] **Flutter** – `template_editor_dialog.dart`: `Text('{$key}')` – zobrazuje **klíč placeholderu** jako label (technické, ne uživatelský překlad); zvážit přesun pod `communication.*` nebo popisek z i18n.
- [ ] **Flutter** – `settings_screen.dart` a podobně: `Text('$flag $label')` – dynamické labely jazyků (OK), ne klasický hardcoded věta.

### `tenant_id` / DTO

- [ ] **Kontrola** – hlavní tabulky automatizace a úkolů mají `tenant_id` + RLS; v appce **safeFrom** tam, kde je to kritické.  
- [ ] **Případné mezery** – při nových DTO vždy zkontrolovat `copyWith` a insert payloady (např. nové moduly).

### Poznámka k uzamčenému souboru

- [ ] **`task_assignment_engine.dart`** – dle pravidel projektu **nesahat**; audit nevyžaduje změny.

---

## 5. Rychlý přehled souborů (reference)

| Oblast | Reprezentativní cesty |
|--------|------------------------|
| Twilio odesílání (server) | `supabase/functions/automation-dispatch/index.ts` |
| Fronta + log | `supabase/migrations/20260320090000_automation_engine_base.sql` |
| Admin Automations UI | `lib/features/admin/admin_automations_screen.dart` |
| Offline issue → AI | `lib/core/offline/offline_issue_task_processor.dart`, `lib/core/offline/drift_mutation_queue_service.dart` |
| SMS počítadlo | `lib/core/utils/sms_counter_utils.dart`, `lib/core/widgets/sms_counter_text_field.dart` |
| WhatsApp z UI | `lib/features/communication/services/whatsapp_sender_service.dart` |

---

*Tento dokument slouží jako živý checklist – při dokončení položky měňte `[ ]` na `[x]`.*
