import 'package:flutter/foundation.dart';

import 'package:falconest/core/services/fcm_registration_feedback.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Repozitář pro zápis FCM tokenů do tabulky [user_devices].
///
/// PROČ samostatný repozitář: Oddělení logiky zápisu od Firebase služby (PushNotificationService).
/// Při selhání upsertu metoda vyhodí výjimku – volající (AuthNotifier) ji zachytí a zaloguje.
/// Žádné tiché polykání chyb – problém se musí dostat do logů/crash reportingu.
class UserDeviceRepository {
  UserDeviceRepository._();

  static final UserDeviceRepository instance = UserDeviceRepository._();

  /// Typ platformy zařízení – pro zápis do user_devices.device_type.
  /// dart:io Platform na webu není dostupný, proto používáme Flutter foundation.
  static String getDeviceType() {
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

  /// Zapíše nebo aktualizuje FCM token v tabulce user_devices.
  ///
  /// Upsert: při konfliktu na fcm_token se provede UPDATE (last_active_at,
  /// profile_id, tenant_id). Tím se zachytí i přihlášení na stejné zařízení
  /// s jiným účtem – token zůstane, ale přiřadí se novému profilu.
  ///
  /// KRITICKÉ: Při chybě (RLS, síť, …) metoda vyhodí výjimku. Volající musí
  /// chybu zachytit a zalogovat – nikdy tiše nepolykat.
  Future<void> upsertToken({
    required String profileId,
    required String tenantId,
    required String fcmToken,
    required String deviceType,
  }) async {
    if (profileId.isEmpty || tenantId.isEmpty || fcmToken.isEmpty) {
      throw ArgumentError(
        'UserDeviceRepository.upsertToken: profileId, tenantId a fcmToken nesmí být prázdné.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();

    try {
      await SupabaseService.client.from('user_devices').upsert(
        SupabaseService.safeInsertPayload(tenantId, {
          'profile_id': profileId,
          'fcm_token': fcmToken,
          'device_type': deviceType,
          'last_active_at': now,
        }),
        onConflict: 'fcm_token',
      );
    } catch (e, st) {
      // PROČ: V release/TestFlight není vidět konzole – červený SnackBar odhalí RLS/síť.
      FcmRegistrationFeedback.showDeviceTokenSaveFailed(e);
      if (kDebugMode) {
        // ignore: avoid_print
        print('UserDeviceRepository.upsertToken ERROR: $e\n$st');
      }
      rethrow;
    }
  }
}
