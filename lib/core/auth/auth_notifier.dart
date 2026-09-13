import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/profile_cache_service.dart';
import 'package:falconest/features/communication/services/template_placeholder_service.dart';
import 'package:falconest/core/services/push_notification_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/services/owner_portal_view_sessions_repository.dart';
import 'package:falconest/features/super_admin/services/support_interventions_repository.dart';

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
/// [isOwnerViewImpersonating] true = admin/manager prohlíží Klientský portál konkrétního majitele (read-only MVP).
/// [impersonatedOwnerProfileId] / [impersonatedOwnerClientId] / [impersonatedOwnerDisplayName] – kontext owner view;
/// platí jen při [isOwnerViewImpersonating]; skutečný profil dispečera zůstává v [profileId].
/// [isTenantActive] = false znamená, že agentura je pozastavena (kill-switch); router
/// přesměruje na /suspended. Null = neznámo (super_admin bez vybrané agentury).
/// [paidUntil] = datum do kdy je předplatné zaplaceno. Pokud now > paidUntil → router
/// přesměruje na /payment-required (Kill Switch pro neplatiče).
class AppAuthState {
  const AppAuthState({
    this.user,
    this.role,
    this.tenantId,
    this.profileId,
    this.isImpersonating = false,
    this.isOwnerViewImpersonating = false,
    this.impersonatedOwnerProfileId,
    this.impersonatedOwnerClientId,
    this.impersonatedOwnerDisplayName,
    this.isTenantActive,
    this.paidUntil,
    this.languageCode,
    this.preferredCurrency,
    this.tenantTimezone,
  });

  final User? user;

  /// Role z profiles – admin, worker, super_admin, property_owner, manager.
  final String? role;

  /// profiles.id – UUID profilu. Pro Worker sync a filtry (assigned_to).
  final String? profileId;

  /// Agentura (tenant) – NULL pro super_admin! Nullable je KRITICKÉ.
  final String? tenantId;

  /// True = Super Admin prohlíží data agentury (režim převtělení).
  final bool isImpersonating;

  /// True = dispečer (admin/manager) prohlíží OwnerLayout jako konkrétní majitel.
  final bool isOwnerViewImpersonating;

  /// profiles.id majitele, jehož portál se zobrazuje (jen při [isOwnerViewImpersonating]).
  final String? impersonatedOwnerProfileId;

  /// clients.id – CRM kontext pro návrat do detailu klienta.
  final String? impersonatedOwnerClientId;

  /// Jméno majitele pro banner „Prohlížíte jako …“.
  final String? impersonatedOwnerDisplayName;

  /// Zda je tenant (agentura) aktivní (is_active). Null = nemáme tenant nebo neznámo.
  final bool? isTenantActive;

  /// Zaplaceno do (tenants.paid_until). NULL = neomezeno. Pokud now > paidUntil → lock screen.
  final DateTime? paidUntil;

  /// Preferovaný jazyk z profiles (cs, en, es). Pro Nastavení a EasyLocalization.
  final String? languageCode;

  /// Preferovaná měna z profiles (CZK, EUR, USD). Pro zobrazení cen v katalogu modulů.
  final String? preferredCurrency;

  /// IANA zóna z `tenants.timezone`. Null = nenačteno; pro šablony použij [effectiveTenantTimezone].
  final String? tenantTimezone;

  /// Vždy platná IANA hodnota (fallback [TemplatePlaceholderService.defaultTenantTimezone]).
  String get effectiveTenantTimezone =>
      TemplatePlaceholderService.normalizeTenantIana(tenantTimezone);

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

  /// Kopie stavu – zachová owner view pole, pokud nejsou explicitně přepsána nebo vymazána.
  AppAuthState copyWith({
    User? user,
    String? role,
    String? tenantId,
    String? profileId,
    bool? isImpersonating,
    bool? isOwnerViewImpersonating,
    String? impersonatedOwnerProfileId,
    String? impersonatedOwnerClientId,
    String? impersonatedOwnerDisplayName,
    bool? isTenantActive,
    DateTime? paidUntil,
    String? languageCode,
    String? preferredCurrency,
    String? tenantTimezone,
    bool clearOwnerViewImpersonation = false,
  }) {
    return AppAuthState(
      user: user ?? this.user,
      role: role ?? this.role,
      tenantId: tenantId ?? this.tenantId,
      profileId: profileId ?? this.profileId,
      isImpersonating: isImpersonating ?? this.isImpersonating,
      isOwnerViewImpersonating: clearOwnerViewImpersonation
          ? false
          : (isOwnerViewImpersonating ?? this.isOwnerViewImpersonating),
      impersonatedOwnerProfileId: clearOwnerViewImpersonation
          ? null
          : (impersonatedOwnerProfileId ?? this.impersonatedOwnerProfileId),
      impersonatedOwnerClientId: clearOwnerViewImpersonation
          ? null
          : (impersonatedOwnerClientId ?? this.impersonatedOwnerClientId),
      impersonatedOwnerDisplayName: clearOwnerViewImpersonation
          ? null
          : (impersonatedOwnerDisplayName ?? this.impersonatedOwnerDisplayName),
      isTenantActive: isTenantActive ?? this.isTenantActive,
      paidUntil: paidUntil ?? this.paidUntil,
      languageCode: languageCode ?? this.languageCode,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      tenantTimezone: tenantTimezone ?? this.tenantTimezone,
    );
  }
}

/// Notifier poslouchající změny Supabase Auth a načítající roli z profiles.
///
/// KRITICKÉ: notifyListeners() se volá POUZE po úspěšném načtení profilu.
/// Nikdy neupozorníme router dříve – tím zajistíme, že redirect má vždy
/// kompletní data (role, tenant_id) a nedojde k race condition.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier([
    SupportInterventionsRepository? repository,
    OwnerPortalViewSessionsRepository? ownerViewSessionsRepository,
  ])  : _repository = repository,
        _ownerViewSessionsRepository = ownerViewSessionsRepository {
    _init();
  }

  AppAuthState _state = const AppAuthState();
  StreamSubscription? _authSubscription;

  /// Repozitář zásahů podpory – při převtělení vytvoří záznam a při ukončení ho uzavře výkazem práce.
  /// PROČ: Prevence zneužití Magic Loginu a podklady pro fakturaci/provize. Null = neinjektováno (testy).
  final SupportInterventionsRepository? _repository;

  /// Audit náhledu Owner portálu z CRM – start/stop session v [owner_portal_view_sessions].
  final OwnerPortalViewSessionsRepository? _ownerViewSessionsRepository;

  /// Pouze v paměti: Super Admin si vybere agenturu ze seznamu. NIKDY neukládat do DB.
  String? _selectedTenantId;

  /// ID aktivního zásahu v support_interventions – nastaví se při startIntervention, vymaže při endIntervention.
  /// Slouží k ukončení zásahu výkazem práce při stopImpersonating.
  String? _activeInterventionId;

  /// ID aktivní session v owner_portal_view_sessions – nastaví se při [startOwnerView], vymaže při [stopOwnerView].
  String? _ownerViewSessionId;

  /// True = Supabase má currentUser, ale profil (role, tenant_id) ještě není načten.
  /// Router NESMÍ dělat rozhodnutí o přesměrování, dokud je true.
  bool _isProfileLoading = false;

  /// Aktuální auth stav – přihlášený uživatel a jeho role.
  AppAuthState get state => _state;

  bool get isLoggedIn => _state.isLoggedIn;
  String? get role => _state.role;

  /// Agentura z DB (profiles.tenant_id). Null pro super_admin.
  String? get tenantId => _state.tenantId;

  /// UUID řádku v `profiles` – např. `completed_by` u položek checklistu.
  /// PROČ: V owner view zůstává profil dispečera; pro filtry majitele použij [effectiveProfileId].
  String? get profileId => _state.profileId;

  /// Profil pro owner dotazy – při owner view impersonation profil majitele, jinak [profileId].
  String? get effectiveProfileId => _state.isOwnerViewImpersonating
      ? _state.impersonatedOwnerProfileId
      : _state.profileId;

  /// Skutečný profil přihlášeného uživatele (dispečer) – pro audit a FCM.
  String? get realProfileId => _state.profileId;

  /// Super Admin: vybraná agentura v UI. Běžný uživatel: vždy null.
  String? get selectedTenantId => _selectedTenantId;

  /// Tenant ID pro načítání dat a filtry v dotazech. Běžný uživatel: tenant_id z profilu.
  /// Super Admin: _selectedTenantId. Null = prázdná data (super_admin bez výběru).
  /// Pro super_admin a account_manager při převtělení = vybraná agentura; jinak tenant z DB.
  String? get tenantIdForData =>
      (_state.role == 'super_admin' || _state.role == 'account_manager')
          ? _selectedTenantId
          : _state.tenantId;

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

  /// Převtělení HQ (Super Admin nebo Account Manager) do vybrané agentury: vytvoří záznam
  /// v support_interventions (audit), uloží výběr v paměti. Volající má po await přesměrovat na context.go('/admin').
  Future<void> impersonateTenant(String tenantId) async {
    if (_state.role != 'super_admin' && _state.role != 'account_manager') return;
    if (_state.isOwnerViewImpersonating) return;
    final id = tenantId.trim();
    if (id.isEmpty) return;

    final profileId = _state.profileId;
    if (profileId != null && profileId.isNotEmpty && _repository != null) {
      try {
        final interventionId = await _repository.startIntervention(profileId, id);
        _activeInterventionId = interventionId;
      } catch (e, st) {
        // Zabraňuje tichému pohlcení chyby při selhání zápisu do support_interventions (P2 audit fix).
        debugPrint('Chyba při zápisu auditu převtělení (startIntervention): $e');
        debugPrint('Stack: $st');
        _activeInterventionId = null;
      }
    }

    bool? isTenantActive;
    DateTime? paidUntil;
    String? impersonationTz;
    try {
      final tenantRes = await SupabaseService.client
          .from('tenants')
          .select('is_active, paid_until, timezone')
          .eq('id', id)
          .maybeSingle();
      if (tenantRes != null) {
        final m = tenantRes as Map;
        final v = m['is_active'];
        isTenantActive = v is bool ? v : (v == true || v == 'true');
        paidUntil = _parseOptionalDateTime(m['paid_until']);
        impersonationTz = _parseTenantTimezoneString(m['timezone']);
      }
    } catch (e, st) {
      AppLogger.error('AuthNotifier: načtení stavu tenanta při startImpersonating selhalo', e, st);
    }

    _selectedTenantId = id;
    _state = _state.copyWith(
      isImpersonating: true,
      isTenantActive: isTenantActive,
      paidUntil: paidUntil,
      tenantTimezone: impersonationTz,
      clearOwnerViewImpersonation: true,
    );
    _ownerViewSessionId = null;
    notifyListeners();
  }

  /// Ukončení režimu převtělení: uzavře zásah v support_interventions (výkaz práce),
  /// vymaže _selectedTenantId a _activeInterventionId. Volající má po await zavolat context.go('/super-admin').
  Future<void> stopImpersonating({String? workReport}) async {
    if (_state.role != 'super_admin' && _state.role != 'account_manager') return;
    final interventionId = _activeInterventionId;
    if (interventionId != null && _repository != null) {
      try {
        await _repository.endIntervention(interventionId, workReport);
      } catch (e, st) {
        // Zabraňuje tichému pohlcení chyby při selhání zápisu do support_interventions (P2 audit fix).
        debugPrint('Chyba při zápisu auditu převtělení (endIntervention): $e');
        debugPrint('Stack: $st');
      }
    }
    _activeInterventionId = null;
    _selectedTenantId = null;
    _state = _state.copyWith(
      isImpersonating: false,
      isTenantActive: null,
      paidUntil: null,
      tenantTimezone: null,
    );
    notifyListeners();
  }

  /// Spuštění náhledu Klientského portálu majitele z CRM (admin/manager, read-only MVP).
  ///
  /// Vytvoří audit záznam v [owner_portal_view_sessions]. Vrací true při úspěchu.
  /// PROČ: Nelze kombinovat s HQ převtělením ([isImpersonating]) – vzájemná exkluze.
  Future<bool> startOwnerView({
    required String clientId,
    required String ownerProfileId,
    required String displayName,
  }) async {
    if (!_state.isAdminOrManager) return false;
    if (_state.isImpersonating) return false;
    if (_state.isOwnerViewImpersonating) return false;

    final cid = clientId.trim();
    final ownerPid = ownerProfileId.trim();
    final name = displayName.trim();
    final tenantId = _state.tenantId?.trim();
    final adminProfileId = _state.profileId?.trim();

    if (cid.isEmpty || ownerPid.isEmpty || tenantId == null || tenantId.isEmpty) {
      return false;
    }
    if (adminProfileId == null || adminProfileId.isEmpty) return false;

    String? sessionId;
    final ownerViewRepo = _ownerViewSessionsRepository;
    if (ownerViewRepo != null) {
      try {
        sessionId = await ownerViewRepo.startSession(
          adminProfileId: adminProfileId,
          viewedOwnerProfileId: ownerPid,
          clientId: cid,
          tenantId: tenantId,
        );
      } catch (e, st) {
        AppLogger.error('AuthNotifier: startOwnerView – zápis audit session selhal', e, st);
        return false;
      }
    }

    _ownerViewSessionId = sessionId;
    _state = _state.copyWith(
      isOwnerViewImpersonating: true,
      impersonatedOwnerProfileId: ownerPid,
      impersonatedOwnerClientId: cid,
      impersonatedOwnerDisplayName: name.isEmpty ? null : name,
    );
    notifyListeners();
    return true;
  }

  /// Ukončení náhledu Owner portálu – uzavře audit session a vymaže stav v paměti.
  Future<void> stopOwnerView() async {
    if (!_state.isOwnerViewImpersonating) return;

    final sessionId = _ownerViewSessionId;
    final ownerViewRepo = _ownerViewSessionsRepository;
    if (sessionId != null &&
        sessionId.isNotEmpty &&
        ownerViewRepo != null) {
      try {
        await ownerViewRepo.endSession(sessionId);
      } catch (e, st) {
        AppLogger.error('AuthNotifier: stopOwnerView – uzavření audit session selhalo', e, st);
      }
    }

    _ownerViewSessionId = null;
    _state = _state.copyWith(clearOwnerViewImpersonation: true);
    notifyListeners();
  }

  /// Znovu načte paid_until z tenants pro aktuálního tenanta. Volá se z PaymentRequiredScreen
  /// („Zkusit znovu“), aby po prodloužení platby Super Adminem router mohl pustit uživatele dál.
  Future<void> refreshTenantPaymentStatus() async {
    final tid = tenantIdForData ?? _state.tenantId;
    if (tid == null || tid.isEmpty) return;
    try {
      final tenantRes = await SupabaseService.client
          .from('tenants')
          .select('paid_until')
          .eq('id', tid)
          .maybeSingle();
      DateTime? paidUntil;
      if (tenantRes != null) {
        paidUntil = _parseOptionalDateTime((tenantRes as Map)['paid_until']);
      }
      _state = _state.copyWith(paidUntil: paidUntil);
      notifyListeners();
    } catch (e, st) {
      AppLogger.error('AuthNotifier: refreshTenantPaymentStatus (paid_until) selhal', e, st);
    }
  }

  static DateTime? _parseOptionalDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static String? _parseTenantTimezoneString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
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
      _activeInterventionId = null;
      _ownerViewSessionId = null;
      _state = const AppAuthState(
        isImpersonating: false,
        isTenantActive: null,
        paidUntil: null,
        preferredCurrency: null,
        tenantTimezone: null,
      );
      // Push notifikace: zrušit listener na obnovu tokenu – uživatel není přihlášen.
      PushNotificationService.instance.dispose();
      // OFFLINE-FIRST: Při odhlášení vymazat cachovaný profil – nesmí zůstat data předchozího uživatele.
      ProfileCacheService.clear();
      notifyListeners();
    }
  }

  /// Zaregistruje FCM token do [user_devices] – pouze pokud má uživatel [tenantId] i [profileId].
  ///
  /// PROČ: Volá se po úspěšném načtení profilu ze Supabase i po offline fallbacku z [ProfileCacheService].
  /// Dříve se FCM po čistě offline startu vůbec nespouštěl → worker bez nového network profilu neměl token v DB.
  /// [unawaited]: neblokovat UI čekáním na APNS; chyby jen do logů.
  void _registerFcmIfTenantUser(String? profileId, String? tenantId) {
    debugPrint('FCM TRACE 1: Profil načten. profileId: $profileId, tenantId: $tenantId');
    if (profileId != null &&
        profileId.isNotEmpty &&
        tenantId != null &&
        tenantId.isNotEmpty) {
      debugPrint('FCM TRACE 2: Volám PushNotificationService.initialize() na pozadí');
      unawaited(
        PushNotificationService.instance
            .initialize(profileId, tenantId)
            .catchError((e, st) {
          // SnackBar už zobrazuje [UserDeviceRepository.upsertToken] při chybě DB.
          debugPrint('CRITICAL FCM ERROR: FCM token registration failed: $e');
          if (kDebugMode) {
            debugPrint('CRITICAL FCM ERROR: $st');
          }
        }),
      );
    } else {
      debugPrint('FCM TRACE 1B: Přeskakuji FCM inicializaci (chybí profil nebo tenant).');
    }
  }

  /// Znovu zaregistruje FCM token (stejná logika jako po načtení profilu).
  ///
  /// PROČ: Po návratu z pozadí může na iOS konečně dorazit APNS token; při studeném startu
  /// mohl první pokus skončit dřív než je token k dispozici. Opakované volání je levné
  /// (Firebase vrátí stejný token, upsert jen obnoví `last_active_at`).
  void retryFcmRegistrationIfLoggedIn() {
    _registerFcmIfTenantUser(_state.profileId, _state.tenantId);
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
              .select('id, role, tenant_id, language_code, preferred_currency')
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
      String? profileIdStr;
      String? languageCodeStr;
      String? preferredCurrencyStr;

      if (res != null && res is Map) {
        final r = res['role'];
        final t = res['tenant_id'];
        final pid = res['id'];
        final lc = res['language_code'];
        final pc = res['preferred_currency'];
        profileIdStr = pid?.toString().trim();
        if (profileIdStr != null && profileIdStr.isEmpty) profileIdStr = null;
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
      DateTime? paidUntil;
      String? tenantTimezoneStr;
      if (tenantIdStr != null && tenantIdStr.isNotEmpty) {
        try {
          final tenantRes = await SupabaseService.client
              .from('tenants')
              .select('is_active, paid_until, timezone')
              .eq('id', tenantIdStr)
              .maybeSingle();
          if (tenantRes != null) {
            final m = tenantRes as Map;
            final v = m['is_active'];
            isTenantActive = v is bool ? v : (v == true || v == 'true');
            paidUntil = _parseOptionalDateTime(m['paid_until']);
            tenantTimezoneStr = _parseTenantTimezoneString(m['timezone']);
          }
        } catch (e, st) {
          AppLogger.error('AuthNotifier: načtení tenants (is_active, paid_until) při loginu selhalo', e, st);
        }
      }

      _state = AppAuthState(
        user: user,
        role: role,
        tenantId: tenantIdStr,
        profileId: profileIdStr,
        isImpersonating: false,
        isTenantActive: isTenantActive,
        paidUntil: paidUntil,
        languageCode: languageCodeStr,
        preferredCurrency: preferredCurrencyStr,
        tenantTimezone: tenantTimezoneStr,
      );

      // Obnovení převtělení po obnovení stránky: pokud HQ (Super Admin nebo Account Manager) měl
      // aktivní zásah (Magic Login), obnovíme _selectedTenantId a _activeInterventionId a stav isImpersonating.
      if ((role == 'super_admin' || role == 'account_manager') &&
          profileIdStr != null &&
          profileIdStr.isNotEmpty &&
          _repository != null) {
        try {
          final active = await _repository.getActiveIntervention(profileIdStr);
          if (active != null) {
            _activeInterventionId = active.id;
            _selectedTenantId = active.tenantId;
            bool? ia;
            DateTime? pu;
            String? tzImp;
            try {
              final tr = await SupabaseService.client
                  .from('tenants')
                  .select('is_active, paid_until, timezone')
                  .eq('id', active.tenantId)
                  .maybeSingle();
              if (tr != null) {
                final m = tr as Map;
                ia = m['is_active'] == true || m['is_active'] == 'true';
                pu = _parseOptionalDateTime(m['paid_until']);
                tzImp = _parseTenantTimezoneString(m['timezone']);
              }
            } catch (e, st) {
              AppLogger.error('AuthNotifier: načtení tenanta při obnově aktivního převtělení selhalo', e, st);
            }
            _state = _state.copyWith(
              isImpersonating: true,
              isTenantActive: ia,
              paidUntil: pu,
              tenantTimezone: tzImp,
            );
          }
        } catch (e, st) {
          AppLogger.error('AuthNotifier: obnovení aktivního support intervention / převtělení selhalo', e, st);
        }
      }

      // Push notifikace: zaregistrovat FCM token zařízení do user_devices.
      _registerFcmIfTenantUser(profileIdStr, tenantIdStr);

      // OFFLINE-FIRST: Uložit profil do lokální cache. Při příštím startu bez sítě
      // (letadlo, sklep, horší signál) AuthNotifier načte z cache místo chybové obrazovky.
      await ProfileCacheService.save(
        CachedProfile(
          authId: user.id,
          role: role,
          profileId: profileIdStr,
          tenantId: tenantIdStr,
          languageCode: languageCodeStr,
          preferredCurrency: preferredCurrencyStr,
          isTenantActive: isTenantActive,
          paidUntil: paidUntil,
          tenantTimezone: _state.tenantTimezone,
          cachedAt: DateTime.now().toUtc(),
        ),
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

      // OFFLINE-FIRST ZÁCHRANNÁ SÍŤ: Při síťové chybě (letadlo, sklep, timeout) zkusit
      // načíst poslední známý profil z lokální cache. Uživatel se dostane do aplikace
      // s cachovanými daty místo chybové obrazovky "Chyba načtení profilu".
      final cached = await ProfileCacheService.load(user.id);
      if (cached != null && cached.authId == user.id) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('DEBUG: Using cached profile for offline fallback. role=${cached.role} tenant_id=${cached.tenantId}');
        }
        _profileLoadError = null;
        _state = AppAuthState(
          user: user,
          role: cached.role,
          tenantId: cached.tenantId,
          profileId: cached.profileId,
          isImpersonating: false,
          isTenantActive: cached.isTenantActive,
          paidUntil: cached.paidUntil,
          languageCode: cached.languageCode,
          preferredCurrency: cached.preferredCurrency,
          tenantTimezone: cached.tenantTimezone,
        );
        _registerFcmIfTenantUser(cached.profileId, cached.tenantId);
      } else {
        // Cache prázdná nebo neplatná – zobrazit chybu jako dosud.
        // NEODHLASOVAT! Uživatel zůstane přihlášen, odhlášení pouze při explicitním kliknutí.
        _profileLoadError = 'login.error_profile_load'.tr();
        _state = AppAuthState(
          user: user,
          role: null,
          tenantId: null,
          profileId: null,
          isImpersonating: false,
          isTenantActive: null,
          paidUntil: null,
          languageCode: null,
          preferredCurrency: null,
          tenantTimezone: null,
        );
      }
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
    final tid = _state.tenantId;
    if (tid != null && tid.isNotEmpty) {
      await SupabaseService.safeFrom('profiles', tid)
          .update({'language_code': trimmed})
          .eq('auth_id', uid);
    } else {
      await SupabaseService.client
          .from('profiles')
          .update({'language_code': trimmed})
          .eq('auth_id', uid);
    }
    _state = _state.copyWith(languageCode: trimmed);
    notifyListeners();
  }

  /// Uloží preferovanou měnu do profiles a aktualizuje stav. Pro zobrazení cen v katalogu modulů (CZK, EUR, USD).
  Future<void> updatePreferredCurrency(String code) async {
    final uid = _state.user?.id;
    if (uid == null || code.trim().isEmpty) return;
    final trimmed = code.trim().toUpperCase();
    final tid = _state.tenantId;
    if (tid != null && tid.isNotEmpty) {
      await SupabaseService.safeFrom('profiles', tid)
          .update({'preferred_currency': trimmed})
          .eq('auth_id', uid);
    } else {
      await SupabaseService.client
          .from('profiles')
          .update({'preferred_currency': trimmed})
          .eq('auth_id', uid);
    }
    _state = _state.copyWith(preferredCurrency: trimmed);
    notifyListeners();
  }

  /// Uloží IANA časovou zónu agentury (`tenants.timezone`). Admin/manager; Super Admin při převtělení předá tenant v RPC.
  Future<void> updateTenantTimezone(String iana) async {
    final normalized = TemplatePlaceholderService.normalizeTenantIana(iana);
    final dataTid = tenantIdForData?.trim();
    final isHq = _state.role == 'super_admin' || _state.role == 'account_manager';

    if (isHq) {
      if (dataTid == null || dataTid.isEmpty) return;
      await SupabaseService.client.rpc(
        'set_tenant_timezone',
        params: {
          'p_timezone': normalized,
          'p_tenant_id': dataTid,
        },
      );
    } else {
      if (!_state.isAdminOrManager) return;
      await SupabaseService.client.rpc(
        'set_tenant_timezone',
        params: {'p_timezone': normalized},
      );
    }

    _state = _state.copyWith(tenantTimezone: normalized);
    notifyListeners();

    final uid = _state.user?.id;
    if (uid != null) {
      await ProfileCacheService.save(
        CachedProfile(
          authId: uid,
          role: _state.role ?? '',
          profileId: _state.profileId,
          tenantId: _state.tenantId,
          languageCode: _state.languageCode,
          preferredCurrency: _state.preferredCurrency,
          isTenantActive: _state.isTenantActive,
          paidUntil: _state.paidUntil,
          tenantTimezone: normalized,
          cachedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
