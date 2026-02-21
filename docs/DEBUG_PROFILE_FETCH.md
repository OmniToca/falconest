# Debug: Chyba načtení profilu (Profile Fetch)

## Co bylo provedeno

1. **Rozšířené logování** v `lib/core/auth/auth_notifier.dart`:
   - Na začátku fetch: `DEBUG: Attempting to fetch profile for Auth ID: <UUID>`
   - Po každém pokusu: `DEBUG: Profile fetch response (attempt X/5): ...`
   - Při PostgrestException: `message`, `code`, `details`, `hint`
   - Při 0 řádcích: `DEBUG: No profile row returned (0 rows). Retrying...`

2. **Fetch logika** – žádný join s `tenants`:
   - Dotaz: `profiles.select(role, tenant_id, language_code, preferred_currency).eq('auth_id', user.id).maybeSingle()`
   - Super Admin s `tenant_id=NULL` je platný stav – aplikace ho správně zpracuje.

3. **Role** se bere z `profiles.role`, ne z `app_super_admins`. Tabulka `app_super_admins` slouží pro RLS funkci `is_super_admin()`.

## SQL pro kontrolu profilu (Supabase SQL Editor)

Spusť **po přihlášení** jako daný uživatel (nebo jako service_role):

```sql
-- 1) Najdi auth.users.id podle emailu
SELECT id, email FROM auth.users WHERE email = 'petr@falconnest.com';

-- 2) Zkontroluj, zda existuje profil s tímto auth_id
SELECT id, auth_id, role, tenant_id, email 
FROM public.profiles 
WHERE auth_id = '<UUID Z BODU 1>';

-- 3) Zkontroluj app_super_admins (pro RLS)
SELECT * FROM public.app_super_admins WHERE id = '<UUID Z BODU 1>';

-- 4) Simulace RLS – co by auth.uid() vrátil při přihlášení:
-- (Spusť jako daný uživatel – v Dashboardu nastav "Run as user" nebo použij REST API s jeho JWT)
```

## Možné příčiny chyby

| Příčina | Řešení |
|---------|--------|
| Profil neexistuje | Spusť skript na povýšení (Super Admin promotion SQL). |
| `auth_id` v profiles neodpovídá `auth.users.id` | Uprav profil: `UPDATE profiles SET auth_id = '<auth.users.id>' WHERE ...` |
| RLS blokuje čtení | Zkontroluj policy `profiles_select`: podmínka `auth_id = auth.uid()` by měla stačit pro vlastní řádek. |
| JWT není v hlavičce včas | Zvýšit delay z 350 ms na 500 ms v `_loadRoleAndNotify`. |
| PostgrestException (např. PGRST116) | Podívej se do konzole na `message` a `code` – typicky 0 řádků nebo RLS. |
