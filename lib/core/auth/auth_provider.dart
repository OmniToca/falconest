import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_notifier.dart';
import 'package:falconest/features/admin/providers/owner_portal_view_sessions_provider.dart';
import 'package:falconest/features/super_admin/providers/support_interventions_provider.dart';

/// Provider pro [AuthNotifier] – poslouchá Supabase Auth a načítá roli z profiles.
///
/// Super Admin má v DB tenant_id == null – to je platný stav. AuthNotifier ho
/// neodhlásí a router ho přesměruje na /super-admin (výběr agentury), ne na chybovou stránku.
///
/// Repozitáře se injektují kvůli auditování HQ převtělení ([support_interventions])
/// a náhledu Owner portálu z CRM ([owner_portal_view_sessions]).
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  final supportRepository = ref.watch(supportInterventionsRepositoryProvider);
  final ownerViewRepository = ref.watch(ownerPortalViewSessionsRepositoryProvider);
  final notifier = AuthNotifier(supportRepository, ownerViewRepository);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});
