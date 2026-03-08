import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_notifier.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/auth/pin_storage.dart';
import 'package:falconest/core/auth/pin_unlock_provider.dart';
import 'package:falconest/core/providers/ui_mode_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/features/auth/auth_loading_screen.dart';
import 'package:falconest/features/auth/invite_screen.dart';
import 'package:falconest/features/auth/login_screen.dart';
import 'package:falconest/features/auth/pin/pin_setup_screen.dart';
import 'package:falconest/features/auth/pin/pin_verify_screen.dart';
import 'package:falconest/features/auth/set_password_screen.dart';
import 'package:falconest/features/auth/update_password_screen.dart';
import 'package:falconest/features/auth/waiting_room_screen.dart';
import 'package:falconest/features/auth/payment_required_screen.dart';
import 'package:falconest/features/auth/suspended_screen.dart';
// import 'package:falconest/features/payment/payment_cancel_screen.dart';
// import 'package:falconest/features/payment/payment_success_screen.dart';
import 'package:falconest/features/public/onboarding_screen.dart';
import 'package:falconest/features/admin/models/module_model.dart';
import 'package:falconest/features/settings/module_editor_screen.dart';
import 'package:falconest/features/admin/admin_zones_screen.dart';
import 'package:falconest/features/settings/settings_screen.dart';
import 'package:falconest/features/super_admin/audit_log_screen.dart';
import 'package:falconest/features/super_admin/onboarding_wizard_screen.dart';
import 'package:falconest/features/super_admin/providers/all_tenants_provider.dart';
import 'package:falconest/features/super_admin/super_admin_dashboard.dart';
import 'package:falconest/features/super_admin/tenant_detail_screen.dart';
import 'package:falconest/features/worker/screens/worker_absences_screen.dart';
import 'package:falconest/features/worker/screens/worker_dashboard_screen.dart';
import 'package:falconest/features/worker/screens/worker_earnings_screen.dart';
import 'package:falconest/features/worker/screens/worker_wallet_screen.dart';
import 'package:falconest/features/worker/screens/worker_task_detail_screen.dart';
import 'package:falconest/features/owner/owner_apartment_detail_screen.dart';
import 'package:falconest/features/owner/owner_layout.dart';
import 'package:falconest/features/tasks/task_detail_screen.dart';
import 'package:falconest/shared/widgets/placeholder_screen.dart';

/// Provider pro GoRouter – závisí na [authNotifierProvider].
///
/// Při změně auth stavu (přihlášení/odhlášení) se router přepočítá díky
/// [refreshListenable]. Globální [redirect] implementuje router guards.
final goRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider);
  final pinUnlocked = ref.watch(pinUnlockedProvider);
  final uiModeNotifier = ref.watch(uiModeNotifierProvider);

  return GoRouter(
    refreshListenable: Listenable.merge([authNotifier, uiModeNotifier]),
    initialLocation: '/',
    // BUGFIX: Oprava definice rout pro klientský portál (zamezení fallback redirectu).
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) async {
      final uiMode = ref.read(uiModeNotifierProvider).mode;
      return _redirectLogic(
        context,
        state,
        authNotifier,
        pinUnlocked,
        uiMode,
        ref,
      );
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Zvací proces: odkaz z e-mailu na /invite?token=... nebo ?id=... (propojení s tabulkou invitations).
      GoRoute(
        path: '/invite',
        name: 'invite',
        builder: (context, state) => const InviteScreen(),
      ),
      GoRoute(
        path: '/pin-setup',
        name: 'pinSetup',
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/pin-verify',
        name: 'pinVerify',
        builder: (context, state) => const PinVerifyScreen(),
      ),
      GoRoute(
        path: '/pin-change',
        name: 'pinChange',
        builder: (context, state) => const PinSetupScreen(isChangeFlow: true),
      ),
      GoRoute(
        path: '/update-password',
        name: 'updatePassword',
        builder: (context, state) => const UpdatePasswordScreen(),
      ),
      GoRoute(
        path: '/set-password',
        name: 'setPassword',
        builder: (context, state) => const SetPasswordScreen(),
      ),
      GoRoute(
        path: '/waiting-room',
        name: 'waitingRoom',
        builder: (context, state) => const WaitingRoomScreen(),
      ),
      GoRoute(
        path: '/auth-loading',
        name: 'authLoading',
        builder: (context, state) => const AuthLoadingScreen(),
      ),
      GoRoute(
        path: '/suspended',
        name: 'suspended',
        builder: (context, state) => const SuspendedScreen(),
      ),
      GoRoute(
        path: '/payment-required',
        name: 'paymentRequired',
        builder: (context, state) => const PaymentRequiredScreen(),
      ),
      // Platební brána zatím odložena – routy pro budoucí Stripe success/cancel
      // GoRoute(
      //   path: '/payment-success',
      //   name: 'paymentSuccess',
      //   builder: (context, state) => const PaymentSuccessScreen(),
      // ),
      // GoRoute(
      //   path: '/payment-cancel',
      //   name: 'paymentCancel',
      //   builder: (context, state) => const PaymentCancelScreen(),
      // ),
      GoRoute(
        path: '/super-admin',
        name: 'superAdmin',
        builder: (context, state) => const SuperAdminDashboard(),
        routes: [
          GoRoute(
            path: 'tenant/:id',
            name: 'tenantDetail',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return TenantDetailScreen(tenantId: id);
            },
            routes: [
              GoRoute(
                path: 'onboarding',
                name: 'onboardingWizard',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return SuperAdminOnboardingWizardScreen(tenantId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'audit-log',
            name: 'auditLog',
            builder: (context, state) => const AuditLogScreen(),
          ),
        ],
      ),
      // Legacy /dashboard → přesměruj na /worker (zpětná kompatibilita)
      GoRoute(path: '/dashboard', redirect: (_, _) => '/worker'),
      GoRoute(
        path: '/worker',
        name: 'worker',
        builder: (context, state) => const WorkerDashboardScreen(),
        routes: [
          GoRoute(
            path: 'absences',
            name: 'workerAbsences',
            builder: (context, state) => const WorkerAbsencesScreen(),
          ),
          GoRoute(
            path: 'wallet',
            name: 'workerWallet',
            builder: (context, state) => const WorkerWalletScreen(),
          ),
          GoRoute(
            path: 'earnings',
            name: 'workerEarnings',
            builder: (context, state) => const WorkerEarningsScreen(),
          ),
          GoRoute(
            path: 'task/:id',
            name: 'workerTaskDetail',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return WorkerTaskDetailScreen(taskId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/task/:id',
        name: 'taskDetail',
        builder: (context, state) {
          final idStr = state.pathParameters['id'] ?? '';
          final taskId = int.tryParse(idStr) ?? 0;
          return TaskDetailScreen(taskId: taskId);
        },
      ),
      // REFACTOR: Přechod z ShellRoute na IndexedStack pro stabilnější navigaci v Klientském portálu.
      GoRoute(
        path: '/owner',
        name: 'owner',
        builder: (context, state) => const OwnerLayout(),
      ),
      // Detail apartmánu – top-level routa pro context.push, zobrazí se přes celou obrazovku.
      GoRoute(
        path: '/owner/apartments/:id',
        name: 'ownerApartmentDetail',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OwnerApartmentDetailScreen(apartmentId: id);
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const PlaceholderScreen(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminLayout(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'zones',
            name: 'zones',
            builder: (context, state) => const AdminZonesScreen(),
          ),
          GoRoute(
            path: 'module',
            name: 'moduleNew',
            builder: (context, state) => const ModuleEditorScreen(),
          ),
          GoRoute(
            path: 'module/:id',
            name: 'moduleEdit',
            builder: (context, state) {
              final extra = state.extra;
              final module = extra is ModuleModel ? extra : null;
              return ModuleEditorScreen(existingModule: module);
            },
          ),
        ],
      ),
    ],
  );
});

/// Vrací cílovou cestu. NEPRŮSTŘELNÁ PRIORITA – super_admin a account_manager PŘED tenant_id!
///
/// 1. role == super_admin NEBO account_manager → vždy /super-admin (nebo /admin při převtělení).
///    Account Manager vidí jen agentury, kde je Lovec/Farmář (filtrace v provideru).
/// 2. tenant_id == null (u ne‑super_admin a ne‑account_manager) → čekárna
/// 3. role == admin/manager → podle [uiMode]: forceMobile→/worker, forceDesktop→/admin,
///    auto→nativní mobil→/worker, web→/admin
/// 4. default → worker
///
/// Důsledek: Super Admin s tenant_id == null v DB nikdy neskončí na čekárně ani odhlášen.
///
/// Směrování podle rolí (Role-based access control).
Future<String?> _getRedirectTargetForRole(
  AuthNotifier authNotifier,
  bool pinUnlocked,
  AdminUiMode uiMode,
) async {
  final role = authNotifier.state.role;
  final tenantId = authNotifier.state.tenantId;

  // Mobil: PIN logika (web ji nemá)
  if (!kIsWeb) {
    final hasPin = await PinStorage.hasPin();
    if (hasPin && !pinUnlocked) return '/pin-verify';
    if (!hasPin) return '/pin-setup';
  }

  // NEPRŮSTŘELNÝ ROUTER – PŘESNĚ TOTO POŘADÍ (bez else-if řetězení).
  // Super_admin a account_manager: HQ role, přesměruj na velín (/super-admin). Při převtělení na /admin.
  if (role == 'super_admin' || role == 'account_manager') {
    if (authNotifier.state.isImpersonating) return '/admin';
    return '/super-admin';
  }
  if (tenantId == null) return '/waiting-room';

  // Admin a Manager: přepínač Web vs. Mobil podle [uiMode].
  // forceMobile = vždy /worker (mobilní UI), forceDesktop = vždy /admin (desktopová administrace).
  // auto = nativní mobil (!kIsWeb) → /worker, web (prohlížeč) → /admin.
  if (role == 'admin' || role == 'manager') {
    switch (uiMode) {
      case AdminUiMode.forceMobile:
        return '/worker';
      case AdminUiMode.forceDesktop:
        return '/admin';
      case AdminUiMode.auto:
        return !kIsWeb ? '/worker' : '/admin';
    }
  }

  if (role == 'property_owner') return '/owner';
  // Worker a personál (cleaner, driver, maintenance) → dashboard personálu
  return '/worker';
}

/// Globální redirect logika (Router Guards).
///
/// Pravidla:
/// 0. Race condition fix: Supabase má user, ale profil se načítá → /auth-loading
/// 1. Nepřihlášený smí na /, /register, /update-password
/// 2. Přihlášený na /: čeká na profil, pak podle role
/// 3. /pin-setup: povoleno když isLoggedIn (mobilní flow)
/// 4. Worker/admin/owner – přístupové omezení
/// 5. P1 (audit): Account Manager smí na detail tenanta jen pokud je Lovec/Farmář u této agentury.
Future<String?> _redirectLogic(
  BuildContext context,
  GoRouterState state,
  AuthNotifier authNotifier,
  bool pinUnlocked,
  AdminUiMode uiMode,
  Ref ref,
) async {
  final location = state.matchedLocation;
  final uri = state.uri;
  final fragment = uri.hasFragment ? uri.fragment : '';
  final supabaseUser = SupabaseService.client.auth.currentUser;
  final isLoggedIn = authNotifier.isLoggedIn;
  final role = authNotifier.role;

  // Pravidlo 0: Deep link – URL obsahuje access_token, podle type přesměrovat
  if (fragment.contains('access_token')) {
    if (fragment.contains('type=invite') && location != '/set-password') {
      return '/set-password';
    }
    if (fragment.contains('type=recovery') && location != '/update-password') {
      return '/update-password';
    }
  }

  // Pravidlo 0a: Password Recovery (Deep link) – VŽDY přesměrovat na /update-password
  if (authNotifier.pendingPasswordRecovery) {
    if (location != '/update-password') {
      return '/update-password';
    }
    return null; // Zůstat na update-password
  }

  // Pravidlo 0b: RACE CONDITION FIX – Supabase má uživatele, ale profil ještě není načten.
  // Neprovádět žádná rozhodnutí o přesměrování, dokud nemáme role a tenant_id.
  if (supabaseUser != null && authNotifier.isProfileLoading) {
    if (location != '/auth-loading') {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Router: Čekám na načtení profilu → přesměrování na /auth-loading');
      }
      return '/auth-loading';
    }
    return null; // Zůstat na loading obrazovce
  }

  // Pravidlo P1 (audit): Account Manager smí na detail tenanta jen pokud je Lovec/Farmář u této agentury.
  // Bez této pojistky by mohl někdo zkusit přístup k cizí agentuře přes přímou URL.
  if (isLoggedIn && role == 'account_manager' && location.startsWith('/super-admin/tenant/')) {
    final match = RegExp(r'^/super-admin/tenant/([^/]+)').firstMatch(location);
    final tenantId = match?.group(1)?.trim();
    if (tenantId != null && tenantId.isNotEmpty) {
      try {
        final allowed = await ref.read(tenantsWithStatusProvider.future);
        final allowedIds = allowed.map((t) => t.tenant.id).toSet();
        if (!allowedIds.contains(tenantId)) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('Router (P1): Account Manager nemá přístup k agentuře $tenantId → přesměrování na nástěnku.');
          }
          return '/super-admin?access_denied=tenant';
        }
      } catch (_) {
        return '/super-admin?access_denied=tenant';
      }
    }
  }

  // Pravidlo 1: Nepřihlášený smí na login (/), registraci (/register),
  // obnovení hesla (/update-password), dokončení invite (/set-password) a zvací obrazovku (/invite).
  if (!isLoggedIn) {
    final path = state.uri.path;
    // Výjimka: Umožňujeme nepřihlášeným uživatelům přístup na zvací obrazovku /invite,
    // aby si mohli nastavit heslo. Query parametry (token) zůstávají v state.uri a jsou dostupné obrazovce.
    if (path == '/invite' || path.startsWith('/invite/')) return null;

    const allowedUnauthenticated = [
      '/',
      '/register',
      '/update-password',
      '/set-password',
      '/invite',
    ];
    if (!allowedUnauthenticated.contains(location)) return '/';
    return null;
  }

  // Pravidlo 1e: Kill-Switch – tenant pozastaven (is_active == false).
  // isTenantActive se bere z profilu (běžný uživatel) nebo z vybrané agentury (Super Admin při převtělení).
  final isTenantActive = authNotifier.state.isTenantActive;
  if (isTenantActive == false && location != '/suspended') {
    return '/suspended';
  }

  // Globální stopka: Zamkne aplikaci všem kromě Super Admina, pokud vypršelo paid_until.
  // Super Admin má vždy absolutní přístup. NULL = neomezeno. Uživatel na /payment-required
  // po prodloužení platby (refreshTenantPaymentStatus) se dostane zpět na Dashboard.
  // paid_until = konec zaplaceného dne; zamykat až po 23:59:59 (ne už o půlnoci).
  final paidUntil = authNotifier.state.paidUntil;
  final now = DateTime.now().toUtc();
  final endOfPaidDay = paidUntil != null
      ? DateTime.utc(paidUntil.year, paidUntil.month, paidUntil.day, 23, 59, 59)
      : null;
  // Kill Switch (paid_until) se nevztahuje na HQ role – super_admin a account_manager.
  if (role != 'super_admin' && role != 'account_manager') {
    if (endOfPaidDay != null && now.isAfter(endOfPaidDay) && location != '/payment-required') {
      return '/payment-required';
    }
    if (location == '/payment-required' && (endOfPaidDay == null || !now.isAfter(endOfPaidDay))) {
      return _getRedirectTargetForRole(authNotifier, pinUnlocked, uiMode);
    }
  }

  // Pravidlo 1a: Přihlášený na /auth-loading – profil už načten, přesměruj podle role
  if (location == '/auth-loading') {
    return _getRedirectTargetForRole(authNotifier, pinUnlocked, uiMode);
  }

  // Pravidlo 1b: Přihlášený na /update-password nebo /set-password – povolit
  if (location == '/update-password' || location == '/set-password') {
    return null;
  }

  // Pravidlo 1c: Super_admin a account_manager na /waiting-room nesmí zůstat – VŽDY pusť na velín
  if ((role == 'super_admin' || role == 'account_manager') && location == '/waiting-room') {
    return '/super-admin';
  }

  // Pravidlo 1d: Uživatel čeká na schválení (tenant_id == null, není HQ role)
  // Smí pouze na /waiting-room, jinak tam přesměruj
  if (role != 'super_admin' && role != 'account_manager' && authNotifier.state.tenantId == null) {
    if (location == '/waiting-room') return null;
    return '/waiting-room';
  }

  // Pravidlo 2a: /pin-setup, /pin-verify, /pin-change – mobilní PIN flow
  if (location == '/pin-setup' || location == '/pin-verify' || location == '/pin-change') {
    if (kIsWeb) return '/'; // Web nemá PIN
    return null; // Zůstat – příslušná obrazovka zobrazí
  }

  // Pravidlo 2b: Přihlášený na / nebo /register – kam přesměrovat
  if (location == '/' || location == '/register') {
    return _getRedirectTargetForRole(authNotifier, pinUnlocked, uiMode);
  }

  // Pravidlo 2b2: Nastavení – přístup pro všechny přihlášené (bez přesměrování)
  if (location == '/settings' || location.startsWith('/settings/')) {
    return null;
  }

  // Pravidlo 2c: Super_admin a account_manager – domovská stránka /super-admin, smí na /admin/*
  // při převtělení (isImpersonating == true). Ochrana: bez převtělení nesmí na /admin.
  if (role == 'super_admin' || role == 'account_manager') {
    if (authNotifier.state.isImpersonating && location.startsWith('/admin')) {
      return null; // Povolit – převtělen, zůstat na /admin
    }
    if (location.startsWith('/admin') && !authNotifier.state.isImpersonating) {
      return '/super-admin'; // HQ bez převtělení nesmí na /admin
    }
    if (location.startsWith('/worker') || location.startsWith('/owner')) {
      return '/super-admin';
    }
  }

  // Pravidlo 2d: Admin/Manager – nesmí na velín; přepínač Web vs. Mobil. Při změně uiMode přesměruj.
  if (role == 'admin' || role == 'manager') {
    if (location.startsWith('/super-admin')) {
      return _getRedirectTargetForRole(authNotifier, pinUnlocked, uiMode);
    }
    if (uiMode == AdminUiMode.forceMobile && location.startsWith('/admin')) {
      return '/worker';
    }
    if (uiMode == AdminUiMode.forceDesktop && location.startsWith('/worker')) {
      return '/admin';
    }
  }

  // Směrování podle rolí (Role-based access control): bezpečnostní zámky (Route Guards).
  // Worker a personál (cleaner, driver, maintenance) nesmí na /admin, /owner ani /super-admin.
  const staffRoles = ['worker', 'cleaner', 'driver', 'maintenance'];
  if (staffRoles.contains(role)) {
    if (location.startsWith('/admin') || location.startsWith('/owner') || location.startsWith('/super-admin')) {
      return '/worker';
    }
  }

  // Pravidlo 4: Property_owner nesmí do admin ani worker
  if (role == 'property_owner') {
    if (location.startsWith('/admin') || location.startsWith('/worker')) {
      return '/owner';
    }
  }

  return null;
}
