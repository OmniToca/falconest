import 'package:flutter/foundation.dart';

import 'package:falconest/core/services/supabase_service.dart';

/// Přihlásí uživatele přes Supabase Email/Password auth.
///
/// Vrací true při úspěchu, false při neúspěchu (špatný e-mail/heslo).
Future<bool> loginWithEmailPassword(String email, String password) async {
  final trimmedEmail = email.trim();
  if (trimmedEmail.isEmpty || password.isEmpty) return false;

  try {
    await SupabaseService.client.auth.signInWithPassword(
      email: trimmedEmail,
      password: password,
    );
    return true;
  } catch (e, stackTrace) {
    debugPrint('🛑 CRITICAL AUTH ERROR: $e');
    debugPrint('STACKTRACE: $stackTrace');
    return false;
  }
}
