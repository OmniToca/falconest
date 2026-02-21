import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_notifier.dart';

/// Provider pro [AuthNotifier] – poslouchá Supabase Auth a načítá roli z profiles.
///
/// Super Admin má v DB tenant_id == null – to je platný stav. AuthNotifier ho
/// neodhlásí a router ho přesměruje na /super-admin (výběr agentury), ne na chybovou stránku.
///
/// ChangeNotifierProvider umožňuje, aby se widgety přebudovaly při notifyListeners()
/// (např. při změně profileLoadError). Používá se též jako refreshListenable v GoRouter.
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  final notifier = AuthNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});
