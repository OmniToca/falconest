import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/repositories/user_device/user_device_repository.dart';

/// Služba pro sběr FCM tokenů zařízení a jejich zápis do databáze.
///
/// ODPOVĚDNOST: Firebase API (requestPermission, getToken, onTokenRefresh).
/// Zápis do Supabase provádí [UserDeviceRepository] – čisté oddělení vrstev.
///
/// **Proč upsert tokenu:** Uživatel může mít více zařízení (telefon + tablet),
/// může aplikaci přeinstalovat (nový token), nebo se může přihlásit na jiný
/// device. Každý platný token musí být v DB – upsert podle fcm_token zajistí,
/// že při opětovném spuštění na stejném zařízení (stejný token) se pouze
/// aktualizuje last_active_at místo vzniku duplicity.
///
/// **Firebase konfigurace:** Pro funkčnost je nutné spustit `flutterfire configure`
/// a mít v projektu Firebase projekt s povoleným Cloud Messaging.
///
/// **Kde se spouští:** [AuthNotifier] po načtení profilu (Supabase) nebo po offline cache –
/// metoda `_registerFcmIfTenantUser` volá [initialize] na pozadí. [main] volá
/// [Firebase.initializeApp] dříve (`DefaultFirebaseOptions`), aby SDK bylo připravené.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService _instance = PushNotificationService._();
  static PushNotificationService get instance => _instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  String? _currentProfileId;
  String? _currentTenantId;

  GoRouter? _router;
  bool _deepLinkListenersAttached = false;

  /// iOS: APNS token často nedorazí okamžitě – bez opakovaného čekání [getToken] hází `apns-token-not-set`.
  static Future<String?> _pollApnsToken({
    int maxAttempts = 15,
    Duration step = const Duration(milliseconds: 700),
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      final t = await FirebaseMessaging.instance.getAPNSToken();
      if (t != null && t.isNotEmpty) return t;
      await Future<void>.delayed(step);
    }
    return null;
  }

  /// Inicializuje FCM a zaregistruje token zařízení v databázi.
  ///
  /// Volá se po úspěšném přihlášení, když máme platný [profileId] a [tenantId].
  /// 1) Požádá o oprávnění k notifikacím
  /// 2) Získá FCM token
  /// 3) Zapíše token do user_devices přes [UserDeviceRepository]
  /// 4) Nastaví listener na obnovu tokenu – při změně se nový token zapíše
  ///
  /// Při chybě zápisu do DB vyhodí výjimku – volající (AuthNotifier) ji zachytí
  /// a zaloguje. Při zamítnutí oprávnění nebo prázdném tokenu tiše vrátí (očekávané).
  Future<void> initialize(String profileId, String tenantId) async {
    debugPrint('FCM TRACE 3: Start initialize()');
    if (profileId.isEmpty || tenantId.isEmpty) return;

    _currentProfileId = profileId;
    _currentTenantId = tenantId;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PushNotificationService: Firebase init failed (skip FCM): $e');
      }
      return;
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return;
      }

      // iOS: notifikace i když je appka na popředí (banner/zvuk) – jinak uživatel „nic nevidí“.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // FIX: Race na iOS – FCM [getToken] potřebuje APNS token; ten přijde často až po několika sekundách.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await _pollApnsToken();
        debugPrint('FCM TRACE 4: APNS token status: $apnsToken');
        if (apnsToken == null) {
          debugPrint(
            'FCM WARNING: APNS token není k dispozici '
            '(Push Capabilities, provisioning, síť). '
            'Notifikace jsou pro tuto relaci deaktivovány.',
          );
          return;
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM TRACE 5: FCM token je NULL, končím.');
        return;
      }
      debugPrint('FCM TRACE 5: Získán FCM token: $token');

      await _writeTokenToDb(profileId, tenantId, token);
      debugPrint('FCM TRACE 6: Token úspěšně zapsán do DB.');

      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (newToken.isNotEmpty &&
            _currentProfileId != null &&
            _currentTenantId != null) {
          _writeTokenToDb(
            _currentProfileId!,
            _currentTenantId!,
            newToken,
          ).catchError((e, st) {
            // SnackBar při chybě DB: [UserDeviceRepository.upsertToken].
            debugPrint('CRITICAL FCM ERROR: onTokenRefresh upsert failed: $e');
            if (kDebugMode) {
              debugPrint('CRITICAL FCM ERROR: $st');
            }
          });
        }
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PushNotificationService.initialize: $e\n$st');
      }
      rethrow;
    }
  }

  /// Zapíše token do DB přes repozitář. Při chybě vyhodí výjimku.
  Future<void> _writeTokenToDb(
    String profileId,
    String tenantId,
    String fcmToken,
  ) async {
    await UserDeviceRepository.instance.upsertToken(
      profileId: profileId,
      tenantId: tenantId,
      fcmToken: fcmToken,
      deviceType: UserDeviceRepository.getDeviceType(),
    );
  }

  /// Zruší listener na obnovu tokenu a vymaže uložený profil.
  /// Volat při odhlášení.
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _messageOpenedSubscription?.cancel();
    _messageOpenedSubscription = null;
    _deepLinkListenersAttached = false;
    _router = null;
    _currentProfileId = null;
    _currentTenantId = null;
  }

  /// Naváže [GoRouter] pro deep link z FCM (`data['route']`).
  ///
  /// PROČ: [getInitialMessage] a [onMessageOpenedApp] potřebují router až po
  /// sestavení [MaterialApp.router]. Volá se z UI po prvním frame (např. z
  /// [FalcoNestApp]). Při nové instanci routeru (refresh provideru) zavolej znovu –
  /// posluchače FCM registrujeme jen jednou, aktualizuje se jen reference na router.
  void attachGoRouter(GoRouter router) {
    _router = router;
    if (_deepLinkListenersAttached) return;
    _deepLinkListenersAttached = true;

    _messageOpenedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateFromFcmData(message.data);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _navigateFromFcmData(message.data);
      }
    });
  }

  /// Vytáhne cílovou cestu z datové části FCM (stejný formát jako [automation-dispatch]).
  static String? routeFromFcmData(Map<String, dynamic> data) {
    final raw = data['route'];
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  void _navigateFromFcmData(Map<String, dynamic> data) {
    final route = routeFromFcmData(data);
    if (route == null) return;
    final router = _router;
    if (router == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        router.go(route);
      } catch (e, st) {
        debugPrint('PushNotificationService: deep link go($route) failed: $e\n$st');
      }
    });
  }
}


