# Deploy checklist – bezpečnost a výkon (P0–P2)

**Účel:** Bezpečně převést kód z repa do produkční Supabase + Flutter web/mobil, aniž by se rozbily crony, média nebo dispečink.

**Datum kódu:** 2026-09-13  
**Migrace v pořadí (timestamp):**

| # | Soubor | Obsah |
|---|--------|--------|
| 1 | `20260913120000_storage_falconest_media_private_rls.sql` | Private bucket + path RLS |
| 2 | `20260913121000_cron_edge_service_role_auth.sql` | Cron → service-role Bearer |
| 3 | `20260913130000_p1_rls_role_split_cash_tasks_invitations.sql` | RLS + `deduct_wallet_credits` |
| 4 | `20260913131000_p1_tasks_composite_indexes.sql` | Indexy tasks |
| 5 | `20260913132000_p2_automation_dispatch_idle_skip.sql` | Idle skip Edge dispatch |

---

## 0) Předpoklady

- [ ] Přístup do Supabase projektu (SQL Editor + Edge Functions + Storage)  
- [ ] `supabase` CLI přihlášené k projektu (`supabase link`) **nebo** ruční deploy z Dashboard  
- [ ] Flutter klient s tímto kódem (signed URL, ne `getPublicUrl`) už připravený k release  
- [ ] Záloha / možnost rollback migrací (alespoň snapshot DB)  

**Pozor:** Po migraci Storage přestanou fungovat **staré public URL** uložené v DB. Klient po novém uploadu ukládá signed URL; historické odkazy je třeba regenerovat nebo znovu nahrát (viz [STORAGE_MEDIA.md](./STORAGE_MEDIA.md)).

---

## 1) Nasazení Edge funkcí (před nebo hned s migrací cronů)

Bez aktualizovaných funkcí cron dostane **401** (vyžadují service role) a `process-issue-ai` / `ical-fetch` / `create-checkout` zůstanou ve starém (nebezpečném) režimu.

```bash
# z kořene repa
supabase functions deploy process-issue-ai
supabase functions deploy create-checkout
supabase functions deploy ical-fetch
supabase functions deploy upcoming-task-reminder
supabase functions deploy daily-task-summary
supabase functions deploy template-reminders
supabase functions deploy automation-enqueue
supabase functions deploy automation-dispatch
# volitelně pokud měníte rent-monitor / sdílený edge_auth import
supabase functions deploy rent-monitor
```

Sdílený modul: `supabase/functions/_shared/edge_auth.ts` se bundluje s funkcemi, které ho importují — deployujte **všechny** funkce výše, které `_shared` používají.

Ověření `config.toml` (gateway):

| Funkce | `verify_jwt` | Autentizace uvnitř |
|--------|--------------|-------------------|
| `process-issue-ai` | `true` | User JWT + profil |
| `create-checkout` | `true` | User JWT + admin/manager |
| `ical-fetch` | `true` | User JWT + admin/manager + host allowlist |
| `upcoming-task-reminder`, `daily-task-summary`, `template-reminders`, `automation-enqueue`, `rent-monitor` | `false` | `requireServiceRoleBearer` |
| `automation-dispatch` | `false` | Service role **nebo** user admin (viz kód) |

Detaily: [EDGE_FUNCTIONS.md](./EDGE_FUNCTIONS.md).

---

## 2) Secrets / env na Edge

V Dashboard → Edge Functions → Secrets (nebo `supabase secrets set`):

| Secret | Použití |
|--------|---------|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` | Obvykle auto od Supabase |
| `STRIPE_SECRET_KEY` | `create-checkout` |
| `STRIPE_ALLOWED_PRICE_IDS` | Volitelný allowlist `price_…` (čárkou) |
| Gemini / AI klíče | `process-issue-ai`, `parse-task-draft` dle stávajícího nastavení |

---

## 3) SQL migrace

```bash
supabase db push
# nebo jednotlivě v SQL Editoru v pořadí timestampů výše
```

Po migraci Storage ověřte:

```sql
SELECT id, public FROM storage.buckets WHERE id = 'falconest_media';
-- očekáváno: public = false
```

---

## 4) `cron_edge_config` (povinné pro crony)

Nahraďte `PROJECT_REF` a vložte **skutečný service role JWT** (Settings → API → `service_role`, secret).

```sql
-- URL (příklad – upravte PROJECT_REF)
UPDATE public.cron_edge_config SET value = 'https://PROJECT_REF.supabase.co/functions/v1/automation-dispatch'
WHERE key = 'automation_dispatch_url';

UPDATE public.cron_edge_config SET value = 'https://PROJECT_REF.supabase.co/functions/v1/automation-enqueue'
WHERE key = 'automation_enqueue_url';

UPDATE public.cron_edge_config SET value = 'https://PROJECT_REF.supabase.co/functions/v1/upcoming-task-reminder'
WHERE key = 'upcoming_task_reminder_url';

UPDATE public.cron_edge_config SET value = 'https://PROJECT_REF.supabase.co/functions/v1/template-reminders'
WHERE key = 'template_reminders_url';

UPDATE public.cron_edge_config SET value = 'https://PROJECT_REF.supabase.co/functions/v1/daily-task-summary'
WHERE key = 'daily_task_summary_url';

UPDATE public.cron_edge_config SET value = 'https://PROJECT_REF.supabase.co/functions/v1/rent-monitor'
WHERE key = 'rent_monitor_url';

-- KRITICKÉ: musí být přesně totéž co SUPABASE_SERVICE_ROLE_KEY ve funkci
UPDATE public.cron_edge_config SET value = 'PASTE_SERVICE_ROLE_JWT_HERE'
WHERE key = 'automation_edge_auth_token';
```

Kontrola klíčů:

```sql
SELECT key,
       CASE WHEN key = 'automation_edge_auth_token'
            THEN left(value, 12) || '…' ELSE value END AS value_preview
FROM public.cron_edge_config
ORDER BY key;
```

Ruční smoke test:

```sql
SELECT public.invoke_automation_dispatch();
SELECT public.invoke_upcoming_task_reminder();
```

- Idle fronta → `invoke_automation_dispatch` smí vrátit **0** (P2 – žádný HTTP).  
- S `pending` splatnou položkou → HTTP 2xx v Edge lozích.  
- Špatný token → Edge log `401 Unauthorized`.

Více: [CRON_AND_AUTOMATION.md](./CRON_AND_AUTOMATION.md).

---

## 5) Flutter klient

1. Release build s tímto kódem (`MediaService` / podpisy → `createSignedUrl`).  
2. `flutter build web --release` (nebo store build).  
3. Smoke: upload fotky k úkolu → URL obsahuje token (ne `/object/public/`).  
4. Admin: Kanban + Nástěnka; worker: výběr hotovosti (vlastní wallet UPDATE).  
5. Invite flow: accept pozvánky (DELETE invitations po propojení profilu).  

---

## 6) Post-deploy ověření (15 min)

| Scénář | Očekávání |
|--------|-----------|
| Anon / bez JWT → `process-issue-ai` | 401 |
| Worker JWT → `create-checkout` | 403 |
| Admin JWT → `ical-fetch` s Airbnb URL | 200 / validní ICS |
| Admin JWT → `ical-fetch` s `http://169.254.169.254/…` | odmítnuto (SSRF) |
| Worker UPDATE cizího úkolu (ne přiřazen) | RLS deny |
| Admin `deduct_wallet_credits` | true při zůstatku |
| Worker `deduct_wallet_credits` | false |
| Cron bez tokenu / špatný token | 401 v Edge logs |
| Prázdná fronta + `invoke_automation_dispatch` | 0, bez Edge invoke |

Diagnostika: [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

---

## 7) Rollback (nouzově)

- **Edge:** redeploy předchozí verze funkce z Gitu / Dashboard historie.  
- **RLS:** nová migrace, která obnoví širší politiky (nedělejte `DROP` bez náhrady v provozu).  
- **Storage public=true:** jen pokud musíte dočasně oživit staré public URL — **bezpečnostní regrese**; preferujte regeneraci signed URL.  
- **Cron token:** vrácení starého anon klíče **nebude** fungovat s novým Edge kódem (vyžaduje service role).
