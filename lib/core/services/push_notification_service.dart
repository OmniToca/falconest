import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:falconest/core/services/supabase_service.dart';

/// Služba pro sběr FCM tokenů zařízení a jejich zápis do Supabase.
///
/// FÁZE 2: Pouze sběr a evidence adres (zápis do user_devices). Zatím neřešíme
/// odesílání zpráv ani zobrazení notifikací v pop-upu.
///
/// **Proč upsert tokenu:** Uživatel může mít více zařízení (telefon + tablet),
/// může aplikaci přeinstalovat (nový token), nebo se může přihlásit na jiný
/// device. Každý platný token musí být v DB – upsert podle fcm_token zajistí,
/// že při opětovném spuštění na stejném zařízení (stejný token) se pouze
/// aktualizuje last_active_at místo vzniku duplicity.
///
/// **Firebase konfigurace:** Pro funkčnost je nutné spustit `flutterfire configure`
/// a mít v projektu Firebase projekt s povoleným Cloud Messaging.
/// Na webu bez Firebase konfigurace se inicializace tiše přeskočí.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService _instance = PushNotificationService._();
  static PushNotificationService get instance => _instance;

  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Typ platformy zařízení – pro zápis do user_devices.device_type.
  /// dart:io Platform na webu není dostupný, proto používáme Flutter foundation.
  static String _getDeviceType() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'web';
    }
  }

  /// Inicializuje FCM a zaregistruje token zařízení v Supabase.
  ///
  /// Volá se po úspěšném přihlášení, když máme platný [profileId] a [tenantId].
  /// 1) Požádá o oprávnění k notifikacím
  /// 2) Získá FCM token
  /// 3) Provede upsert do tabulky user_devices (fcm_token jako unikátní klíč)
  /// 4) Nastaví listener na obnovu tokenu – při změně (reinstall, logout/jiný účet)
  ///    se nový token okamžitě zapíše do DB
  ///
  /// Při chybě (Firebase nekonfigurován, odmítnuté oprávnění) se tiše vrátí
  /// – neblokuje přihlášení uživatele.
  Future<void> initialize(String profileId, String tenantId) async {
    if (profileId.isEmpty || tenantId.isEmpty) return;

    try {
      // Firebase může být již inicializovaný v main() – pak apps.isNotEmpty.
      // Bez flutterfire configure může init selhat (chybí google-services.json apod.).
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('PushNotificationService: Firebase init failed (skip FCM): $e');
      }
      return;
    }

    try {
      // 1) Požádat o oprávnění (iOS zobrazí systémový dialog).
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('PushNotificationService: Notification permission denied.');
        }
        return;
      }

      // 2) Získat aktuální token.
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      // 3) Upsert do Supabase – fcm_token je UNIQUE, při shodě se aktualizuje řádek.
      await _upsertToken(
        profileId: profileId,
        tenantId: tenantId,
        fcmToken: token,
      );

      // 4) Listener na obnovu tokenu – Firebase může token změnit (vypršení, reinstall).
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (newToken.isNotEmpty) {
          _upsertToken(
            profileId: profileId,
            tenantId: tenantId,
            fcmToken: newToken,
          ).catchError((e) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('PushNotificationService: onTokenRefresh upsert failed: $e');
            }
          });
        }
      });
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('PushNotificationService: initialize failed: $e');
      }
    }
  }

  /// Zruší listener na obnovu tokenu. Volat při odhlášení.
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  /// Zapíše nebo aktualizuje token v tabulce user_devices.
  ///
  /// Upsert: při konfliktu na fcm_token se provede UPDATE (last_active_at,
  /// profile_id, tenant_id). Tím se zachytí i přihlášení na stejné zařízení
  /// s jiným účtem – token zůstane, ale přiřadí se novému profilu.
  Future<void> _upsertToken({
    required String profileId,
    required String tenantId,
    required String fcmToken,
  }) async {
    final deviceType = _getDeviceType();
    final now = DateTime.now().toUtc().toIso8601String();

    await SupabaseService.client.from('user_devices').upsert(
      {
        'tenant_id': tenantId,
        'profile_id': profileId,
        'fcm_token': fcmToken,
        'device_type': deviceType,
        'last_active_at': now,
      },
      onConflict: 'fcm_token',
    );
  }
}
