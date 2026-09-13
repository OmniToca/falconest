# RLS a role – co platí po P1

Migrace: `20260913130000_p1_rls_role_split_cash_tasks_invitations.sql`  
Helpery: `is_tenant_admin_or_manager()`, `is_worker_assigned_to_task()`, `is_super_admin()`, `my_tenant_id()`.

## Matice oprávnění (zjednodušeně)

### `tasks`

| Operace | Kdo |
|---------|-----|
| SELECT | Člen tenanta (stávající tenant policy) / super_admin; worker sync filtruje přiřazení na klientu |
| INSERT | Tenant (owner report issue, admin, …) – beze změny širokého INSERT |
| **UPDATE** | **admin/manager** celý tenant **nebo** worker, kde `is_worker_assigned_to_task(id)` |
| DELETE | Stávající tenant policy (soft-delete v app) |

**Provoz:** Worker nesmí měnit cizí úkoly. Pokud „nejde změnit status“, zkontrolujte `assigned_to` / `assigned_user_ids`.

### `employee_cash_wallets`

| Operace | Kdo |
|---------|-----|
| INSERT | admin/manager **nebo** `profile_id` = vlastní profil (první výběr hotovosti) |
| UPDATE | admin/manager **nebo** vlastní `profile_id` (navýšení balance při collect) |
| SELECT | dle stávajících tenant politik |

### `employee_cash_transactions`

| Operace | Kdo |
|---------|-----|
| INSERT | v rámci tenanta (worker collect / admin handover) – široké INSERT zachováno |
| **UPDATE** | **jen** admin/manager (např. shortfall resolution) |

### `invitations`

| Operace | Kdo |
|---------|-----|
| INSERT / UPDATE | admin/manager (+ super_admin) |
| DELETE | admin/manager **nebo** řádek s `profile_id` = můj profil (flow **accept invite**) |

Accept: po `signUp` + propojení ghost profilu klient maže pozvánku — nový uživatel ještě není admin.

### RPC `deduct_wallet_credits(tenant_id, amount, type, ref)`

Povoleno pouze:

- `is_super_admin()`, nebo  
- `is_tenant_admin_or_manager()` **a** `profiles.tenant_id` == `p_tenant_id`.

Jinak vrací **`false`** (nestrhne). Generátor úkolů / automatické strhávání musí běžet pod admin session.

---

## Co se v UI nesmí změnit (smoke)

1. Worker: COLLECTED_FROM_GUEST → wallet balance ↑.  
2. Admin: Převzít hotovost / FIFO handover.  
3. Admin: shortfall UPDATE na transakci.  
4. Admin: změna statusu libovolného úkolu.  
5. Worker: změna statusu **svého** úkolu.  
6. Pozvánka personálu + accept na `/invite`.  
7. Admin: generování návrhů úkolů (stržení kreditů).

---

## Diagnostika RLS

V SQL Editoru (jako uživatel nelze snadno — použijte app log / PostgREST):

- Kód `42501` / message „new row violates row-level security“ / „permission denied“.  
- Flutter: `PostgrestException` v `AppLogger`.  

Dočasně (jen staging): porovnejte `auth.uid()` s `profiles` a `assigned_to` úkolu.

```sql
-- Diagnostika přiřazení (service role / SQL jako admin DB)
SELECT id, assigned_to, assigned_user_ids, status
FROM public.tasks
WHERE id = 'TASK_UUID';
```

---

## Indexy P1 (výkon, ne RLS)

`idx_tasks_tenant_scheduled_start`, `idx_tasks_tenant_completed_at` — zrychlí měsíční / ops filtry.  
Ověření: `\d+ tasks` nebo:

```sql
SELECT indexname FROM pg_indexes
WHERE tablename = 'tasks' AND indexname LIKE 'idx_tasks_tenant_%';
```
