# Edge Functions – autentizace a použití

Zdroj pravdy: `supabase/functions/`, `supabase/config.toml`, `_shared/edge_auth.ts`.

## Společné helpery (`_shared/edge_auth.ts`)

| Funkce | Chování |
|--------|---------|
| `requireServiceRoleBearer(req)` | `Authorization` musí být přesně `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`. Jinak **401**. |
| `requireUserProfile(req)` | Bearer = user access token → `auth.getUser` → řádek `profiles` (`auth_id`). Vrací user client (RLS) + `{ id, tenantId, role }`. |

Role kontroly v jednotlivých funkcích typicky: `admin` / `manager` / `super_admin`.

---

## Matice funkcí

### Uživatelské (Flutter volá s session JWT)

#### `process-issue-ai`

- **Gateway:** `verify_jwt = true`  
- **Auth:** `requireUserProfile`  
- **Pravidla:** `tenant_id` a `created_by` se berou z profilu, ne z body. Insert přes user client (RLS).  
- **Volá:** Worker / offline processor po hlášení závady (AI překlad / nadpis).  
- **Chyby:** 401 bez JWT; 403 bez profilu.

#### `create-checkout`

- **Gateway:** `verify_jwt = true`  
- **Auth:** profil + musí být admin/manager tenanta z body **nebo** super_admin.  
- **Body:** `tenant_id`, `email`, `price_id`, `success_url`, `cancel_url`.  
- **Validace:** `price_id` ~ `^price_[A-Za-z0-9]+$`; volitelně env `STRIPE_ALLOWED_PRICE_IDS`.  
- **Volá:** HQ / billing UI při nákupu kreditů / modulů.  
- **Chyby:** 403 worker/owner; 400 špatný price.

#### `ical-fetch`

- **Gateway:** `verify_jwt = true`  
- **Auth:** admin/manager (nebo super_admin).  
- **Anti-SSRF:** hostname musí končit na allowlist (Airbnb, Booking, Guesty, Hostaway, Lodgify, Smoobu, Beds24, VRBO, Google/Outlook kalendář, …). Blok privátních IP, limit velikosti/timeout.  
- **Volá:** `IcalSyncService` z Adminu.  
- **Chyba „není na allowlistu“:** přidejte suffix do `ALLOWED_ICAL_HOST_SUFFIXES` v `ical-fetch/index.ts` a znovu deployněte (ne do DB).

#### `parse-task-draft` (AI prefill úkolu)

- Používá Gemini structured client; ověřte secrets a JWT podle aktuálního `index.ts` / `config.toml`.  
- Volá Admin dialog „Z textu“.

---

### Cron / interní (Bearer = service role)

Všechny následující mají v `config.toml` **`verify_jwt = false`** a uvnitř `requireServiceRoleBearer` (nebo ekvivalent u `automation-dispatch` / `rent-monitor`).

| Funkce | Volá z DB | Účel |
|--------|-----------|------|
| `upcoming-task-reminder` | `invoke_upcoming_task_reminder()` | Reminder úkolů |
| `daily-task-summary` | `invoke_daily_task_summary()` | Denní souhrn |
| `template-reminders` | `invoke_template_reminders()` | Šablony transferů |
| `automation-enqueue` | `invoke_automation_enqueue()` | Plánování fronty |
| `automation-dispatch` | `invoke_automation_dispatch()` | Odeslání fronty (Twilio/FCM/…) |
| `rent-monitor` | `invoke_rent_monitor()` | Long-term nájem due |
| `ses-hospedajes` | `invoke_ses_hospedajes()` | SOAP SES Hospedajes + poll lote + SLA alert |

**Token v DB:** `cron_edge_config.automation_edge_auth_token` musí == `SUPABASE_SERVICE_ROLE_KEY`.

HTTP helper: `public._automation_invoke_http_post(p_url_key)` čte URL klíč + token a POSTuje s `Authorization: Bearer …`.

---

### Webhooky (bez Supabase JWT)

| Funkce | Autentizace |
|--------|-------------|
| `resend-webhook` | Svix / `RESEND_WEBHOOK_SECRET` |
| `twilio-webhook` | `X-Twilio-Signature` + `TWILIO_AUTH_TOKEN` |
| `export_calendar` | hash `export_token` v URL + RPC |

---

## Jak volat z Flutteru (pattern)

```dart
await Supabase.instance.client.functions.invoke(
  'process-issue-ai',
  body: { /* bez důvěryhodného tenant_id – server ho přepíše */ },
);
// Klient automaticky posílá aktuální session JWT v Authorization.
```

Pro cron **nikdy** nevolejte z mobilu se service role klíčem.

---

## Lokální vývoj

```bash
supabase functions serve process-issue-ai --env-file supabase/.env.local
```

V `.env.local` musí být stejné klíče jako v Dashboard. Pro test cronu:

```bash
curl -i -X POST 'http://127.0.0.1:54321/functions/v1/upcoming-task-reminder' \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

Bez Bearer → 401.
