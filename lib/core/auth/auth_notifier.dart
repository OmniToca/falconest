import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/services/supabase_service.dart';

/// Stav přihlášeného uživatele (efektivní „profile model“) – role a tenant_id z profiles.
///
/// Aplikace nemá samostatný user_model.dart / profile_model.dart; parsování profilu
/// probíhá v [AuthNotifier._loadRoleAndNotify] a výsledek se ukládá sem. [tenantId]
/// MUSÍ BÝT NULLABLE (String?) – Super Admin má v DB tenant_id VŽDY null.
/// fromJson-ekvivalent (načtení z Supabase) null u tenant_id zvládá a nesmí spadnout.
///
/// Pro načítání dat (RLS / filtry) používej [AuthNotifier.tenantIdForData]:
/// - běžný uživatel: tenant_id z profilu;
/// - Super Admin: vybraná agentura (_selectedTenantId, pouze v paměti, NIKDY neukládat do DB).
/// [isImpersonating] true = Super Admin prohlíží data jedné agentury (vybraná v UI).
/// [isTenantActive] = false znamená, že agentura je pozastavena (kill-switch); router
/// přesměruje na /suspended. Null = neznámo (super_admin bez vybrané agentury).
class AppAuthState {
  const AppAuthState({
    this.user,
    this.role,
    this.tenantId,
    this.isImpersonating = false,
    this.isTenantActive,
    this.languageCode,
    this.preferredCurrency,
  });

  final User? user;

  /// Role z profiles – admin, worker, super_admin, property_owner, manager.
  final String? role;

  /// Agentura (tenant) – NULL pro super_admin! Nullable je KRITICKÉ.
  final String? tenantId;

  /// True = Super Admin prohlíží data agentury (režim převtělení).
  final bool isImpersonating;

  /// Zda je tenant (agentura) aktivní (is_active). Null = nemáme tenant nebo neznámo.
  final bool? isTenantActive;

  /// Preferovaný jazyk z profiles (cs, en, es). Pro Nastavení a EasyLocalization.
  final String? languageCode;

  /// Preferovaná měna z profiles (CZK, EUR, USD). Pro zobrazení cen v katalogu modulů.
  final String? preferredCurrency;

  bool get isLoggedIn => user != null;

  bool get isSuperAdmin => role == 'super_admin';

  /// Uživatel čeká na schválení – má roli, ale nemá přiřazenou agenturu.
  /// Nesmí do aplikace, pouze na /waiting-room.
  bool get isAwaitingApproval =>
      !isSuperAdmin && user != null && tenantId == null;

  /// Zda má uživatel roli admin nebo manager (plný přístup).
  bool get isAdminOrManager => role == 'admin' || role == 'manager';

  /// Zda je uživatel worker (přístup pouze do /worker).
  bool get isWorker => role == 'worker';

  /// Zda je uživatel majitel bytu (přístup pouze do /owner).
  bool get isPropertyOwner => role == 'property_owner';
}

/// Notifier poslouchající změny Supabase Auth a načítající roli z profiles.
///
/// KRITICKÉ: notifyListeners() se volá POUZE po úspěšném načtení profilu.
/// Nikdy neupozorníme router dříve – tím zajistíme, že redirect má vždy
/// kompletní data (role, tenant_id) a nedojde k race condition.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    _init();
  }

  AppAuthState _state = const AppAuthState();
  StreamSubscription? _authSubscription;

  /// Pouze v paměti: Super Admin si vybere agenturu ze seznamu. NIKDY neukládat do DB.
  String? _selectedTenantId;

  /// True = Supabase má currentUser, ale profil (role, tenant_id) ještě není načten.
  /// Router NESMÍ dělat rozhodnutí o přesměrování, dokud je true.
  bool _isProfileLoading = false;

  /// Aktuální auth stav – přihlášený uživatel a jeho role.
  AppAuthState get state => _state;

  bool get isLoggedIn => _state.isLoggedIn;
  String? get role => _state.role;

  /// Agentura z DB (profiles.tenant_id). Null pro super_admin.
  String? get tenantId => _state.tenantId;

  /// Super Admin: vybraná agentura v UI. Běžný uživatel: vždy null.
  String? get selectedTenantId => _selectedTenantId;

  /// Tenant ID pro načítání dat a filtry v dotazech. Běžný uživatel: tenant_id z profilu.
  /// Super Admin: _selectedTenantId. Null = prázdná data (super_admin bez výběru).
  String? get tenantIdForData =>
      _state.role == 'super_admin' ? _selectedTenantId : _state.tenantId;

  /// Zda ještě probíhá načítání profilu. Pokud true, router má zobrazit loading.
  bool get isProfileLoading => _isProfileLoading;

  /// Chyba při načítání profilu – po odhlášení zobrazit SnackBar a vynulovat.
  String? _profileLoadError;
  String? get profileLoadError => _profileLoadError;
  void clearProfileLoadError() {
    _profileLoadError = null;
    notifyListeners();
  }

  /// True = uživatel přišel z odkaz pro obnovu hesla (Deep link).
  /// Router přesměruje na /update-password.
  bool _pendingPasswordRecovery = false;
  bool get pendingPasswordRecovery => _pendingPasswordRecovery;
  void clearPendingPasswordRecovery() {
    _pendingPasswordRecovery = false;
    notifyListeners();
  }

  /// True = uživatel přišel z invite e-mailu a má dokončit registraci (heslo).
  /// Router přesměruje na /set-password.
  bool _pendingInviteCompletion = false;
  bool get pendingInviteCompletion => _pendingInviteCompletion;
  void setPendingInviteCompletion(bool value) {
    _pendingInviteCompletion = value;
    notifyListeners();
  }
  void clearPendingInviteCompletion() {
    _pendingInviteCompletion = false;
    notifyListeners();
  }

  /// Vynucené znovunačtení profilu (po registraci s pozvánkou).
  Future<void> reloadProfile() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      _isProfileLoading = true;
      notifyListeners();
      await _loadRoleAndNotify(user);
    }
  }

  /// Převtělení Super Admina do vybrané agentury: uloží výběr POUZE v paměti
  /// (_selectedTenantId). NIKDY neukládáme do DB (profiles zůstává tenant_id: null).
  /// Volající má po await přesměrovat na context.go('/admin').
  Future<void> impersonateTenant(String tenantId) async {
    if (_state.role != 'super_admin') return;
    final id = tenantId.trim();
    if (id.isEmpty) return;

    bool? isTenantActive;
    try {
      final tenantRes = await SupabaseService.client
          .from('tenants')
          .select('is_active')
          .eq('id', id)
          .maybeSingle();
      if (tenantRes != null) {
        final v = (tenantRes as Map)['is_active'];
        isTenantActive = v is bool ? v : (v == true || v == 'true');
      }
    } catch (_) {}

    _selectedTenantId = id;
    _state = AppAuthState(
      user: _state.user,
      role: _state.role,
      tenantId: _state.tenantId,
      isImpersonating: true,
      isTenantActive: isTenantActive,
      languageCode: _state.languageCode,
      preferredCurrency: _state.preferredCurrency,
    );
    notifyListeners();
  }

  /// Ukončení režimu převtělení: vymaže pouze _selectedTenantId v paměti.
  /// Do DB se nic nezapisuje. Volající má po await zavolat context.go('/super-admin').
  Future<void> stopImpersonating() async {
    if (_state.role != 'super_admin') return;
    _selectedTenantId = null;
    _state = AppAuthState(
      user: _state.user,
      role: _state.role,
      tenantId: _state.tenantId,
      isImpersonating: false,
      isTenantActive: null,
      languageCode: _state.languageCode,
      preferredCurrency: _state.preferredCurrency,
    );
    notifyListeners();
  }

  /// Inicializace – odběr auth streamu a prvotní načtení stavu.
  void _init() {
    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      _onAuthChange,
    );

    // Prvotní načtení – pokud je uživatel už přihlášen (např. refresh stránky)
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      _isProfileLoading = true;
      _loadRoleAndNotify(user);
    } else {
      notifyListeners();
    }
  }

  /// Reakce na změnu auth stavu – přihlášení, odhlášení, refresh tokenu,
  /// obnovení hesla (Deep link).
  void _onAuthChange(AuthState authState) {
    // Zachytit password recovery – uživatel přišel z e-mailového odkazu
    if (authState.event == AuthChangeEvent.passwordRecovery) {
      _pendingPasswordRecovery = true;
      final user = authState.session?.user;
      if (user != null) {
        _isProfileLoading = true;
        _loadRoleAndNotify(user);
      } else {
        _isProfileLoading = false;
        notifyListeners();
      }
      return;
    }

    final user = authState.session?.user;
    if (user != null) {
      _isProfileLoading = true;
      _loadRoleAndNotify(user);
    } else {
      _pendingPasswordRecovery = false;
      _isProfileLoading = false;
      _selectedTenantId = null;
      _state = const AppAuthState(isImpersonating: false, isTenantActive: null, preferredCurrency: null);
      notifyListeners();
    }
  }

  /// Načte roli a tenant_id z tabulky profiles. Po úspěchu upozorní posluchače.
  ///
  /// KRITICKÉ – Super Admin a null tenant_id:
  /// U Super Admina je v DB tenant_id VŽDY null. To je platný stav, NE chyba.
  /// Aplikace ho nesmí odhlásit ani přesměrovat na čekárnu – router ho pošle na /super-admin.
  ///
  /// Retry mechanismus: Při registraci signUp přihlásí uživatele dřív, než
  /// registrační funkce stihne udělat upsert do profiles. Pokud profil není
  /// nalezen, čekáme 1 s a zkoušíme znovu (max 4 pokusy = až 4 s).
  ///
  /// RLS / Race condition: Po přihlášení může první request odjet dřív, než
  /// klient nastaví JWT do hlavičky – pak auth.uid() v DB je null a RLS vrátí 0 řádků.
  /// Krátké počáteční zpoždění (350 ms) dává Supabase klientu čas připojit session k dalšímu requestu.
  Future<void> _loadRoleAndNotify(User user) async {
    try {
      if (kDebugMode) {
        // ignore: avoid_print
        print('DEBUG: Attempting to fetch profile for Auth ID: ${user.id}');
      }

      // Dát Supabase klientu čas připojit novou session (JWT) k dalším requestům.
      // Bez toho může první dotaz na profiles odjet s prázdným auth a RLS vrátí 0 řádků.
      await Future.delayed(const Duration(milliseconds: 350));

      // Aktualizace last_sign_in_at v public.profiles pro Tenant Health na Super Admin dashboardu.
      // Pro všechny role (Super Admin, Agency Admin, Worker). Nepřerušit přihlášení při chybě.
      try {
        if (kDebugMode) {
          // ignore: avoid_print
          print('DEBUG: Attempting to update last_sign_in_at for auth_id=${user.id}');
        }
        await SupabaseService.client
            .from('profiles')
            .update({'last_sign_in_at': DateTime.now().toUtc().toIso8601String()})
            .eq('auth_id', user.id);
        if (kDebugMode) {
          // ignore: avoid_print
          print('DEBUG: last_sign_in_at updated successfully.');
        }
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('DEBUG: last_sign_in_at update failed (non-fatal): $e');
          if (e is PostgrestException) {
            // ignore: avoid_print
            print('DEBUG: PostgrestException message=${e.message} code=${e.code} details=${e.details}');
          }
        }
      }

      dynamic res;
      const maxAttempts = 5;

      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        try {
          if (kDebugMode && attempt == 0) {
            // ignore: avoid_print
            print('DEBUG: Profile fetch query: profiles.select(role,tenant_id,language_code,preferred_currency).eq(auth_id,${user.id}).maybeSingle()');
          }
          final response = await SupabaseService.client
              .from('profiles')
              .select('role, tenant_id, language_code, preferred_currency')
              .eq('auth_id', user.id)
              .isFilter('deleted_at', null)
              .maybeSingle();

          if (kDebugMode) {
            // ignore: avoid_print
            print('DEBUG: Profile fetch response (attempt ${attempt + 1}/$maxAttempts): $response');
          }

          dynamic raw = response;
          if (raw is List && raw.isNotEmpty) {
            raw = raw.first;
          }
          if (raw != null && raw is Map) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('DEBUG: Profile found: role=${raw['role']} tenant_id=${raw['tenant_id']}');
            }
            res = raw;
            break;
          }
        } on PostgrestException catch (e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('DEBUG: PROFILE FETCH PostgrestException: message=${e.message} code=${e.code} details=${e.details}');
          }
          rethrow;
        } catch (e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('DEBUG: PROFILE FETCH ERROR (attempt ${attempt + 1}): $e');
          }
          rethrow;
        }

        if (attempt < maxAttempts - 1) {
          // Prodleva před dalším pokusem (registrace / RLS timing).
          if (kDebugMode) {
            // ignore: avoid_print
            print('DEBUG: No profile row returned (0 rows). Retrying in ${attempt == 0 ? 500 : 1000}ms...');
          }
          await Future.delayed(Duration(milliseconds: attempt == 0 ? 500 : 1000));
        } else {
          res = null;
        }
      }

      String? roleStr;
      String? tenantIdStr;
      String? languageCodeStr;
      String? preferredCurrencyStr;

      if (res != null && res is Map) {
        final r = res['role'];
        final t = res['tenant_id'];
        final lc = res['language_code'];
        final pc = res['preferred_currency'];
        if (lc is String && lc.trim().isNotEmpty) languageCodeStr = lc.trim();
        if (pc is String && pc.trim().isNotEmpty) preferredCurrencyStr = pc.trim().toUpperCase();
        // ignore: avoid_print
        print('DEBUG: Surové role=$r (typ: ${r.runtimeType}), tenant_id=$t (typ: ${t.runtimeType})');

        roleStr = r is String ? r : (r?.toString());
        // tenant_id MŮŽE BÝT NULL – Super Admin ho v DB nemá. Nikdy to nepovažovat za chybu.
        if (t == null) {
          tenantIdStr = null;
        } else if (t is String) {
          tenantIdStr = t.isEmpty ? null : t;
        } else {
          tenantIdStr = t.toString();
        }
      } else {
        if (kDebugMode) {
          // ignore: avoid_print
          print('DEBUG: Profile NOT FOUND after $maxAttempts attempts. auth_id=${user.id}');
          // ignore: avoid_print
          print('DEBUG: Possible causes: RLS blocks read, profile row missing, or auth_id mismatch.');
        }
        throw Exception(
          'Profil pro auth_id=${user.id} nenalezen (0 řádků po $maxAttempts pokusech). '
          'Možné příčiny: RLS blokuje čtení (zkontroluj profiles_select policy), '
          'záznam v profiles chybí, nebo auth_id v DB neodpovídá auth.users.id. '
          'Super Admin: ověř, že profiles má řádek s auth_id=<UUID> a role=super_admin.',
        );
      }

      final role = (roleStr != null && roleStr.trim().isNotEmpty)
          ? roleStr.trim()
          : null;
      if (role == null || role.isEmpty) {
        throw Exception(
          'Profil má prázdnou nebo null roli. role=$roleStr',
        );
      }

      // ignore: avoid_print
      print('DEBUG: Finální role="$role", tenant_id=$tenantIdStr');
      // Pro role == super_admin je tenantIdStr == null očekávaný stav – nepřesměrovávat na čekárnu.

      bool? isTenantActive;
      if (tenantIdStr != null && tenantIdStr.isNotEmpty) {
        try {
          final tenantRes = await SupabaseService.client
              .from('tenants')
              .select('is_active')
              .eq('id', tenantIdStr)
              .maybeSingle();
          if (tenantRes != null) {
            final v = (tenantRes as Map)['is_active'];
            isTenantActive = v is bool ? v : (v == true || v == 'true');
          }
        } catch (_) {}
      }

      _state = AppAuthState(
        user: user,
        role: role,
        tenantId: tenantIdStr,
        isImpersonating: false,
        isTenantActive: isTenantActive,
        languageCode: languageCodeStr,
        preferredCurrency: preferredCurrencyStr,
      );
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('DEBUG: PROFILE FETCH FAILED - Auth ID: ${user.id}');
        // ignore: avoid_print
        print('DEBUG: Exception type: ${e.runtimeType}');
        if (e is PostgrestException) {
          // ignore: avoid_print
          print('DEBUG: PostgrestException message=${e.message} code=${e.code} details=${e.details} hint=${e.hint}');
        } else {
          // ignore: avoid_print
          print('DEBUG: Exception: $e');
        }
        // ignore: avoid_print
        print('DEBUG: Stack trace: $st');
      }

      // NEODHLASOVAT! Uživatel zůstane přihlášen, zobrazíme chybu.
      // Odhlášení pouze při explicitním kliknutí na Odhlásit se.
      _profileLoadError = 'login.error_profile_load'.tr();
      _state = AppAuthState(user: user, role: null, tenantId: null, isImpersonating: false, isTenantActive: null, languageCode: null, preferredCurrency: null);
    } finally {
      _isProfileLoading = false;
      notifyListeners();
    }
  }

  /// Uloží preferovaný jazyk do profiles a aktualizuje stav. Volající má po await zavolat context.setLocale(Locale(code)).
  Future<void> updateLanguageCode(String code) async {
    final uid = _state.user?.id;
    if (uid == null || code.trim().isEmpty) return;
    final trimmed = code.trim();
    await SupabaseService.client
        .from('profiles')
        .update({'language_code': trimmed})
        .eq('auth_id', uid);
    _state = AppAuthState(
      user: _state.user,
      role: _state.role,
      tenantId: _state.tenantId,
      isImpersonating: _state.isImpersonating,
      isTenantActive: _state.isTenantActive,
      languageCode: trimmed,
      preferredCurrency: _state.preferredCurrency,
    );
    notifyListeners();
  }

  /// Uloží preferovanou měnu do profiles a aktualizuje stav. Pro zobrazení cen v katalogu modulů (CZK, EUR, USD).
  Future<void> updatePreferredCurrency(String code) async {
    final uid = _state.user?.id;
    if (uid == null || code.trim().isEmpty) return;
    final trimmed = code.trim().toUpperCase();
    await SupabaseService.client
        .from('profiles')
        .update({'preferred_currency': trimmed})
        .eq('auth_id', uid);
    _state = AppAuthState(
      user: _state.user,
      role: _state.role,
      tenantId: _state.tenantId,
      isImpersonating: _state.isImpersonating,
      isTenantActive: _state.isTenantActive,
      languageCode: _state.languageCode,
      preferredCurrency: trimmed,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
