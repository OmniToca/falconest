import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/presentation/root_scaffold_messenger.dart';

/// Záchranná zpětná vazba při selhání zápisu FCM tokenu do `user_devices`.
///
/// PROČ: [debugPrint] v release není vidět; červený SnackBar ukáže Postgrest/RLS/síť přímo uživateli.
class FcmRegistrationFeedback {
  FcmRegistrationFeedback._();

  /// Červený SnackBar s textem výjimky (RLS, síť, …).
  static void showDeviceTokenSaveFailed(Object error) {
    final text = error is PostgrestException
        ? '${error.message} (code=${error.code ?? '?'})'
        : error.toString();

    void show() {
      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger == null) {
        debugPrint('FCM token DB (no messenger): $text');
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB71C1C),
          content: Text(
            'FCM token DB: $text',
            style: const TextStyle(color: Colors.white),
            maxLines: 6,
          ),
          duration: const Duration(seconds: 12),
        ),
      );
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 400), show);
    });
  }
}
