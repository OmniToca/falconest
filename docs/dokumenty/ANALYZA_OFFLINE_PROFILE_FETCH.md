# Analýza: Offline profil a „Chyba načtení profilu“

## 1. Lokalizace

**Widget/obrazovka zobrazující text „Chyba načtení profilu“:**

- **Soubor:** `lib/features/auth/waiting_room_screen.dart`
- **Klíč:** `profileError ?? 'waiting_room.message'.tr()` – pokud `profileError != null`, zobrazí se chybový text
- **i18n klíč:** `login.error_profile_load` (`assets/translations/cs.json`)

**Kde se `profileLoadError` nastavuje:**

- `lib/core/auth/auth_notifier.dart`, řádek 517: `_profileLoadError = 'login.error_profile_load'.tr();`
- Nastavuje se v bloku `catch` metody `_loadRoleAndNotify`, když dojde k jakékoli výjimce při načítání profilu ze sítě.

---

## 2. Trasování logiky

### Tok při startu aplikace (uživatel již přihlášen)

```
main() 
  → SupabaseService.init()
  → database_init.initDatabase() (Isar na mobilu)
  → runApp()
    → AuthNotifier vytvořen (authNotifierProvider)
      → AuthNotifier._init()
        → SupabaseService.client.auth.onAuthStateChange.listen(_onAuthChange)
        → user = SupabaseService.client.auth.currentUser
        → pokud user != null:
            _isProfileLoading = true
            _loadRoleAndNotify(user)  ← SYŇOVÝ POŽADAVEK
```

### Co dělá `_loadRoleAndNotify(user)`:

1. Počká 350 ms (kvůli JWT/session)
2. Volitelně aktualizuje `last_sign_in_at` v `profiles` (update přes Supabase)
3. Provádí smyčku (max 5 pokusů):
   - `SupabaseService.client.from('profiles').select(...).eq('auth_id', user.id).maybeSingle()`
4. Pokud profil existuje:
   - Načte `tenants` pro `is_active` a `paid_until`
   - Sestaví `AppAuthState` a uloží do `_state`
5. Při výjimce:
   - Nastaví `_profileLoadError`
   - Vyčistí role/tenant v `_state` (ale ponechá `user`)
   - `notifyListeners()`

### Router (`app_router.dart`)

- `supabaseUser != null && isProfileLoading` → `/auth-loading` (loading)
- Po dokončení: `_getRedirectTargetForRole` → podle `role` a `tenantId`:
  - `tenantId == null` (a nejde o super_admin) → `/waiting-room`
- Na `/waiting-room` se zobrazí `WaitingRoomScreen`, který při `profileLoadError != null` zobrazí chybovou zprávu a tlačítko „Odhlásit se“.

### Shrnutí kritického bodu

- Síťový požadavek na `profiles` a `tenants` **probíhá vždy** při startu, pokud je uživatel přihlášen.
- Při offline (např. letadlo) dotaz selže (SocketException / TimeoutException / ClientException).
- Dojde k výjimce → `catch` → `_profileLoadError` → přesměrování na `/waiting-room` → aplikace nepoužitelná.

---

## 3. Vysvětlení – zapojené komponenty

| Komponenta | Soubor | Úloha |
|------------|--------|-------|
| **AuthNotifier** | `auth_notifier.dart` | Poslouchá Supabase Auth, volá `_loadRoleAndNotify`, drží `_state`, `_profileLoadError` |
| **authNotifierProvider** | `auth_provider.dart` | Riverpod provider pro AuthNotifier |
| **GoRouter** | `app_router.dart` | Redirect podle `isProfileLoading`, `role`, `tenantId`, `profileLoadError` |
| **WaitingRoomScreen** | `waiting_room_screen.dart` | Zobrazuje chybu při `profileLoadError != null` |
| **AuthLoadingScreen** | `auth_loading_screen.dart` | Loading indikátor během načítání profilu |
| **SupabaseService** | `supabase_service.dart` | Klient pro dotazy na `profiles` a `tenants` |

### Proměnné v AuthNotifier

- `_state` (AppAuthState): user, role, tenantId, profileId, isTenantActive, paidUntil, …
- `_profileLoadError`: chybový text nebo null
- `_isProfileLoading`: true během volání `_loadRoleAndNotify`
- `_selectedTenantId`: pouze pro Super Admin (převtělení)

### Kde chybí fallback na lokální databázi

- **Žádné uložení profilu do Isar ani jiné lokální paměti** – po úspěšném načtení se profil nikam neukládá.
- **Žádné čtení z cache při síťové chybě** – při výjimce se okamžitě nastaví chyba a uživatel je odeslán na waiting-room.
- **Isar** obsahuje: ApartmentLocal, TaskLocal, ReservationLocal, PendingAuditAction – **ProfileLocal neexistuje**.

### Výjimky při offline

- `SocketException` (dart:io) – typické pro mobil
- `TimeoutException` (dart:async)
- `ClientException` (z HTTP stacku Supabase)
- Případně další obalové výjimky

---

## 4. Návrh řešení (mikroskopický řez) – IMPLEMENTOVÁNO

1. **ProfileCacheService** (`lib/core/auth/profile_cache_service.dart`) – nová služba s SharedPreferences:
   - `save(CachedProfile)` – uloží profil po úspěšném síťovém načtení
   - `load(authId)` – načte cache při síťové chybě (fallback)
   - `clear()` – vymaže při odhlášení

2. **AuthNotifier._loadRoleAndNotify** – změny:
   - Po úspěšném načtení: volá `ProfileCacheService.save(...)`
   - V bloku `catch`: před nastavením `_profileLoadError` volá `ProfileCacheService.load(user.id)`; pokud cache existuje a `auth_id` sedí, sestaví `_state` z cache a nepoužije chybu
   - Jinak zůstává původní chování (zobrazení chyby)

3. **AuthNotifier._onAuthChange** – při `user == null` (odhlášení): volá `ProfileCacheService.clear()`

4. **Platforma** – SharedPreferences funguje na webu i mobilu. Isar se nepoužívá pro profil (jednodušší, bez nového schématu).
