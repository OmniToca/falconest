# Šablony + Automatizace – striktní audit stavu kódu (repo)

*Zdroj pravdy: soubory v tomto repozitáři. Nasazení na konkrétní Supabase projekt zde neověřujeme.*

---

## 1. DATABÁZE (Supabase migrace)

### `tenant_message_templates`
- **✅ Hotovo (kde to je)**  
  - Po migraci `supabase/migrations/20260322180000_channels_refactoring_templates.sql`: sloupce **`body`** a **`language_code`** jsou **DROP** (řádky 45–47).  
  - Aktuální struktura v téže migraci: **`email_subject`**, **`translations` (jsonb)**, **`channel`** s constraintem  
    `tenant_message_templates_channel_check` → **`CHECK (channel IN ('sms', 'email', 'whatsapp'))`** (ř. 60–62).  
  - Původní CHECK s `whatsapp_link` je odstraněn smyčkou `DROP CONSTRAINT` (ř. 21–40); data `whatsapp_link` → `whatsapp` (ř. 52–58).  
  - Základ tabulky: `supabase/migrations/20260231200000_tenant_message_templates.sql` (dnes přepsaný refaktorem výše).

### `automation_rules` a `automation_message_queue`
- **✅ Hotovo (kde to je)**  
  - Obě tabulky: `supabase/migrations/20260320090000_automation_engine_base.sql`.  
  - **`ENABLE ROW LEVEL SECURITY`** + politiky `SELECT`/`INSERT`/`UPDATE`/`DELETE` pro `authenticated` s `my_tenant_id()` / `is_super_admin()` (u pravidel navíc kontrola `template_id` → `tenant_message_templates` téhož tenanta).

### `tenant_message_log` – `direction`, `inbound_text`
- **✅ Hotovo (kde to je)**  
  - Migrace `supabase/migrations/20260323100000_tenant_message_log_inbound_direction.sql`:  
    - `direction text NOT NULL DEFAULT 'outbound'` + **`CHECK (direction IN ('outbound', 'inbound'))`**  
    - `inbound_text text NULL`  
    - `queue_id` **nullable** (inbound bez fronty)  
    - přepsaná INSERT politika pro `inbound` + `queue_id IS NULL` vs `outbound` + existující fronta  

### CRON – `automation-enqueue` / `automation-dispatch`
- **❌ Chybí**  
  - V `supabase/migrations/**/*.sql` **není** žádný `cron.schedule` / `pg_cron` volající `automation-enqueue` nebo `automation-dispatch` (grep bez výsledku).  
  - V repu **je** `pg_cron` pro jiné věci (např. `template-reminders`): `supabase/migrations/20260231220000_template_reminders_notifications.sql`.

---

## 2. CLOUD (Edge Functions – TypeScript)

### `automation-enqueue`
- **✅ Hotovo (kde to je)**  
  - `supabase/functions/automation-enqueue/index.ts`: typ šablony má **`translations`**, **`email_subject`**, **`channel`** (ř. ~44–48); select šablon **`.select("id, translations, email_subject, channel")`** (ř. ~376).  
  - Text zprávy: **`resolveTemplateContent(translations, …)`** – komentář explicitně uvádí, že sloupce **`body` / `language_code` v DB nejsou** (ř. ~186–188).  
  - **`email_subject`**: dedikovaná logika `resolveEmailSubject` / zápis do `editable_payload.email_subject` (ř. ~214–316, ~530+ podle kontextu enqueue).  
- **⚠️ Částečně**  
  - „Vyřazení starého `body`“ = **na úrovni šablony v DB** hotové; v **payloadu fronty** pořád existuje klíč **`text`** (generovaný z překladů), což je záměr, ne DB sloupec `body`.

### `automation-dispatch`
- **✅ Hotovo (kde to je)**  
  - `supabase/functions/automation-dispatch/index.ts`:  
    - **SMS**: `sendViaTwilioSms` → Twilio REST `Messages.json`, návrat **SID**.  
    - **WhatsApp**: `sendViaTwilioWhatsApp` (prefix `whatsapp:`), fallback WA→SMS ve `sendWithSmartFallback`.  
    - **E-mail**: `sendViaResendEmail` → `POST https://api.resend.com/emails`, Bearer **`RESEND_API_KEY`**, návrat **`id`**.  
    - Volitelně **`TWILIO_STATUS_CALLBACK_URL`** na formuláři Twilio (`appendTwilioStatusCallback`).  
  - Log: `external_api_id` + Twilio/Resend ID; **`extractEmailSubjectFromEditablePayload`** pro předmět e-mailu.

### Webhooky `twilio-webhook` a `twilio-inbound`
- **✅ Hotovo (kde to je)**  
  - **`twilio-webhook`**: `supabase/functions/twilio-webhook/index.ts` – POST, `URLSearchParams` z raw těla, update `tenant_message_log` podle `MessageSid` / `MessageStatus`, service role, 200 + TwiML.  
  - **`twilio-inbound`**: `supabase/functions/twilio-inbound/index.ts` – POST form-urlencoded, `From`/`Body`/`MessageSid`, kanál z prefixu `whatsapp:`, routing tenant přes **`clients.phone`** a **`reservations.guest_phone`**, insert inbound do `tenant_message_log`, 200 + TwiML.  
- **⚠️ Částečně**  
  - Ověření **`X-Twilio-Signature`** je v obou souborech jen jako komentář / MVP (není implementované v kódu).

---

## 3. FLUTTER FRONTEND (Dart & UI)

### Editor šablon
- **✅ Hotovo (kde to je)**  
  - `lib/features/communication/widgets/template_editor_dialog.dart`: **`SegmentedButton`** pro kanál (`sms` / `email` / `whatsapp`), **`TabBar` + `TabBarView`** pro jazyky (cs/en/es), texty jen v **`translations`** přes controllery `_bodyByLang`.  
  - Předmět e-mailu: zobrazen jen pokud `_channel == 'email'` (`_emailSubjectController`).  
  - **SMS počítadlo**: `SmsCounterInfo` jen pokud `_channel == 'sms'` (ř. ~257–258).  
  - Model **`MessageTemplateRow`** (`lib/features/communication/models/message_template_row.dart`): **žádný** top-level sloupec `body` z DB – jen **`translations`**, **`email_subject`**.  
  - Lokální worker model **`MessageTemplateLocal`**: text z **`translationsJson`**, komentář „žádný legacy sloupec“ (`message_template_local.dart`).

### Editor pravidel – filtr šablon podle kanálu
- **✅ Hotovo (kde to je)**  
  - `lib/features/admin/admin_automation_rule_form.dart`: **`_templatesForSelectedChannel`**, dropdown šablon z **`filtered`**, při změně kanálu **`_onChannelChanged`** resetuje **`_selectedTemplateId`** (ř. ~162–175, ~444–499).

### Čekárna a historie
- **Příchozí (inbound) v historii**  
  - **✅ Hotovo (kde to je)**  
    - `lib/core/models/automation/tenant_message_log_row.dart`: **`direction`**, **`inboundText`**, nullable **`queueId`**.  
    - `lib/features/admin/providers/automation_log_repository.dart`: select obsahuje **`direction`**, **`inbound_text`**.  
    - `lib/features/admin/admin_automations_screen.dart` – **`_LogCard`**: větev **`isInbound`**, text **`inboundText ?? contentSnapshot`**, vizuální odlišení (bublina, `Icons.call_received`, lokalizační klíč `admin.log_direction_inbound`).  

- **Tlačítko „Odeslat okamžitě“ z Čekárny**  
  - **❌ Chybí**  
    - `admin_automations_screen.dart` – záložka fronty: **`_QueueCard`** má akce **Zrušit** / **Upravit text** (`onCancel`, `onEdit`); **žádné** volání dispatch ani „send now“ v tomto souboru.

---

## Shrnutí symbolů

| Oblast | Stav |
|--------|------|
| DB šablony (bez legacy `body`, channel CHECK) | ✅ v migraci `20260322180000_*` |
| DB automation tabulky + RLS | ✅ v `20260320090000_*` |
| DB log `direction` / `inbound_text` | ✅ v `20260323100000_*` |
| pg_cron pro enqueue/dispatch | ❌ v migracích není |
| Edge enqueue (translations + email subject) | ✅ |
| Edge dispatch (Twilio SMS/WA + Resend) | ✅ |
| Edge twilio-webhook + twilio-inbound | ✅ kód v repu; podpis Twilio ⚠️ ne |
| Flutter šablony (SegmentedButton, TabBar, SMS counter) | ✅ |
| Flutter pravidla (filtr šablon podle kanálu) | ✅ |
| Flutter historie inbound | ✅ |
| Flutter „odeslat okamžitě“ ve frontě | ❌ |
