import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_notifier.dart';
import 'package:falconest/features/super_admin/providers/support_interventions_provider.dart';

/// Provider pro [AuthNotifier] – poslouchá Supabase Auth a načítá roli z profiles.
///
/// Super Admin má v DB tenant_id == null – to je platný stav. AuthNotifier ho
/// neodhlásí a router ho přesměruje na /super-admin (výběr agentury), ne na chybovou stránku.
///
/// Repozitář zásahů podpory se injektuje kvůli auditování Magic Loginu (support_interventions).
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  final repository = ref.watch(supportInterventionsRepositoryProvider);
  final notifier = AuthNotifier(repository);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});
