# Cron a automatizace – provozní návod

## Architektura (stručně)

```
pg_cron  →  invoke_*()  →  _automation_invoke_http_post(url_key)
         →  POST Edge Function
         →  Authorization: Bearer <automation_edge_auth_token>
```

Tabulka **`public.cron_edge_config`** (key/value):

| Key | Význam |
|-----|--------|
| `automation_edge_auth_token` | **Service role JWT** (sdílený pro všechny `_automation_invoke_http_post`) |
| `automation_dispatch_url` | URL Edge `automation-dispatch` |
| `automation_enqueue_url` | URL Edge `automation-enqueue` |
| `upcoming_task_reminder_url` | … |
| `template_reminders_url` | … |
| `daily_task_summary_url` | … |
| `rent_monitor_url` | … |
| `ses_hospedajes_url` | Edge `ses-hospedajes` (SOAP SES) |

RLS na `cron_edge_config` je zapnuté — běžný tenant uživatel hodnoty nečte. Úpravy jen přes SQL Editor / service role.

---

## Prvotní nastavení (nový projekt)

1. Deploy Edge funkcí (viz [DEPLOY_SECURITY_P0_P2.md](./DEPLOY_SECURITY_P0_P2.md)).  
2. Doplňte URL a token SQL výše.  
3. Ověřte joby v `cron.job` (Integrations → Cron nebo):

```sql
SELECT jobid, jobname, schedule, command
FROM cron.job
ORDER BY jobname;
```

Očekávané (názvy se mohou lišit dle migrací):

- `automation-dispatch-1m` → `* * * * *` → `SELECT public.invoke_automation_dispatch();`  
- `automation-enqueue-15m` → `*/15 * * * *`  
- reminder / template / daily / rent-monitor dle příslušných migrací  

4. Smoke: `SELECT public.invoke_automation_enqueue();` a zkontrolujte Edge logs.

---

## P0 změna autentizace (2026-09)

Dříve některé crony volaly Edge s **anon key**.  
Nově Edge vyžaduje **service role Bearer**. Migrace `20260913121000_…` přepisuje `invoke_*` na `_automation_invoke_http_post`.

Pokud po deployi crony „umlknou“:

1. Edge log = `401` → špatný / chybějící `automation_edge_auth_token`.  
2. Token = anon key → neprojde (`requireServiceRoleBearer` porovnává se `SUPABASE_SERVICE_ROLE_KEY`).  
3. URL stále `REPLACE_WITH_PROJECT_REF` → funkce se nevolá (`RAISE NOTICE` v DB lozích).

Legacy klíče typu `template_reminders_anon_key` / `upcoming_task_reminder_anon_key` **už invoke funkce nepoužívají** — nechte je nebo smažte, ale nespoléhejte na ně.

---

## P2: idle skip u `automation-dispatch`

Migrace `20260913132000_p2_automation_dispatch_idle_skip.sql`:

`invoke_automation_dispatch()` nejdřív:

```sql
EXISTS (
  SELECT 1 FROM automation_message_queue
  WHERE status = 'pending' AND scheduled_for <= now()
  LIMIT 1
)
```

- **false** → return `0`, **žádný** HTTP na Edge (šetří náklady).  
- **true** → POST jako dřív.

Minutový cron zůstává — jen se vyhne prázdným invoke.

### Kdy idle skip „zlobí“

- Položky ve stavu `processing` / `failed` se **nespočítají** jako práce (stejně jako Edge picker bere jen `pending`).  
- Zaseknuté `processing` řešte ručně (reset na `pending` / `failed`) — mimo tento dokument.

---

## Fronta pro dispečera (UI)

Admin „Čekárna“ čte `automation_message_queue` se statusem typicky `pending`.  
„Odeslat okamžitě“ jde přes Edge `automation-dispatch` s **user JWT** (admin/manager) — viz autorizace uvnitř `automation-dispatch/index.ts` (ne jen service role).

---

## Rotace service role klíče

1. Vygenerujte / zkopírujte nový service role v Dashboard.  
2. `UPDATE cron_edge_config SET value = '…' WHERE key = 'automation_edge_auth_token';`  
3. Edge runtime má klíč automaticky — ověřte `SELECT public.invoke_rent_monitor();` (nebo jiný lehký job).  
4. Staré JWT ihned přestane fungovat.

**Nikdy** necommitujte token do Gitu ani do `docs/`.
