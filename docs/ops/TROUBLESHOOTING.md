# Troubleshooting – provoz po P0–P2

## 1) Edge vrací 401 Unauthorized

| Příčina | Řešení |
|---------|--------|
| Cron volá bez Bearer / se starým anon key | Nastavte `automation_edge_auth_token` = service role JWT |
| Token ≠ `SUPABASE_SERVICE_ROLE_KEY` ve funkci | Znovu zkopírujte z Dashboard → API |
| Flutter volá cron funkci s user JWT | Cron funkce očekávají service role — z Flutteru je nevolejte |
| `verify_jwt=true` + neplatný user JWT | Obnovte session / odhlášení přihlášení |

Log: `[edge_auth] 401 – Neplatný nebo chybějící service-role Authorization`.

---

## 2) Edge vrací 403

| Funkce | Typická příčina |
|--------|-----------------|
| `create-checkout` | Volá worker/owner, ne admin/manager |
| `ical-fetch` | Stejně – jen dispečer |
| `process-issue-ai` | Chybí řádek v `profiles` pro `auth_id` |

---

## 3) iCal sync selže „Hostitel není na allowlistu“

1. Zjistěte hostname feedu.  
2. Pokud je legitimní PMS, přidejte suffix do `ALLOWED_ICAL_HOST_SUFFIXES` v `supabase/functions/ical-fetch/index.ts`.  
3. `supabase functions deploy ical-fetch`.  

Privátní IP / metadata endpointy jsou záměrně blokované (SSRF).

---

## 4) Obrázky / účtenky 404 nebo broken image

1. Je URL stále `…/object/public/…`? → bucket je private; regenerujte signed URL.  
2. Signed URL vypršela? (TTL 10 let — u starších ručních odkazů kratší.)  
3. Path mimo `tenant_id/` → storage RLS.  
4. Ověřte `MediaService` v nasazeném buildu (ne starý klient s `getPublicUrl`).

---

## 5) Worker nemůže dokončit úkol / změnit status

P1 UPDATE policy: musí být přiřazen (`assigned_to` nebo `assigned_user_ids`).  
Admin musí úkol přiřadit; nebo dočasně opravit data.

---

## 6) Worker nemůže vybrat hotovost

- INSERT transakce OK, UPDATE wallet fail → policy wallets (musí být vlastní `profile_id`).  
- Volá se s cizím `profile_id`? Bug v klientu.  
- Peněženka neexistuje → INSERT vlastní wallet musí projít.

---

## 7) `deduct_wallet_credits` vrací false

- Nedostatek kreditu, **nebo**  
- Volající není admin/manager/super_admin, **nebo**  
- `p_tenant_id` ≠ tenant profilu.  

Zkontrolujte, že generátor běží pod admin session.

---

## 8) Accept invite padá na DELETE invitations

Policy dovoluje delete jen adminovi nebo vlastníkovi `profile_id`.  
Po kroku propojení ghost profilu musí být `auth.uid()` napojen na `invitations.profile_id`.  
Pokud trigger vytvořil druhý profil, klient se snaží smazat duplicit — to může RLS tiše ignorovat; kritické je smazání řádku pozvánky.

---

## 9) Automatizace „neběží“, ale cron job existuje

1. `SELECT public.invoke_automation_dispatch();` → `0` při prázdné frontě je **OK** (P2).  
2. Vložte test `pending` + `scheduled_for <= now()` a znovu invoke.  
3. Edge logs – 401 vs 200.  
4. URL v `cron_edge_config` bez `REPLACE_WITH_…`.

```sql
SELECT id, status, scheduled_for, channel
FROM public.automation_message_queue
WHERE status = 'pending'
ORDER BY scheduled_for
LIMIT 20;
```

---

## 10) Admin UI pomalé i po P1

Očekávané zlepšení: 1 ops Realtime místo 2 (dashboard+workload), úzký select, lite jména.  
Stále běží samostatně: měsíční Kanban stream + apartment status stream.  
Ověřte indexy (`idx_tasks_tenant_scheduled_start`).  
Velký tenant + Realtime dump až 15k řádků je limitem SDK (jeden filtr = `tenant_id`).

---

## Rychlé SQL „health“

```sql
-- Bucket
SELECT public FROM storage.buckets WHERE id = 'falconest_media';

-- Cron token nastaven?
SELECT key, length(value) AS len
FROM public.cron_edge_config
WHERE key = 'automation_edge_auth_token';

-- Splatná fronta
SELECT count(*) FROM public.automation_message_queue
WHERE status = 'pending' AND scheduled_for <= now();

-- Indexy P1
SELECT indexname FROM pg_indexes
WHERE indexname IN (
  'idx_tasks_tenant_scheduled_start',
  'idx_tasks_tenant_completed_at'
);
```
