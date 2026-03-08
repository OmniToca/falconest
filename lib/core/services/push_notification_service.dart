import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService _instance = PushNotificationService._();
  static PushNotificationService get instance => _instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentProfileId;
  String? _currentTenantId;

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

      // FIX: Race condition na iOS – getToken() vyžaduje APNS token, který se
      // inicializuje asynchronně. Bez čekání vzniká chyba [apns-token-not-set].
      // Ochrana: Pokud APNS po čekání zůstane null, nevolat getToken() – vyhodil by
      // apns-token-not-set a způsobil Riverpod crash v AuthNotifier.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          await Future<void>.delayed(const Duration(seconds: 3));
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        }
        debugPrint('FCM TRACE 4: APNS token status: $apnsToken');
        if (apnsToken == null) {
          debugPrint(
            'FCM WARNING: APNS token není k dispozici '
            '(zkontrolujte Xcode Capabilities nebo Apple Developer účet). '
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
            debugPrint('CRITICAL FCM ERROR: onTokenRefresh upsert failed: $e');
            if (kDebugMode) {
              debugPrint('CRITICAL FCM ERROR: $st');
            }
          });
        }
      });
    } catch (e) {
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
    _currentProfileId = null;
    _currentTenantId = null;
  }
}


