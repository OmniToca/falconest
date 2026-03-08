import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/super_admin/services/support_interventions_repository.dart';

/// Provider repozitáře pro zásahy podpory (support_interventions).
///
/// PROČ: AuthNotifier potřebuje při převtělení vytvořit záznam a při ukončení ho uzavřít;
/// zároveň Super-Admin potřebuje načíst seznam výkazů práce. Repozitář je sdílený.
final supportInterventionsRepositoryProvider =
    Provider<SupportInterventionsRepository>((ref) => SupportInterventionsRepository());

/// Seznam zásahů podpory (výkazy práce) pro Super-Admina – historie Magic Loginu.
///
/// PROČ: Obrazovka „Výkazy práce“ v HQ zobrazuje Kdo, Kdy, Jak dlouho, Agentura, Poznámka.
/// Data slouží jako audit a podklad pro fakturaci a provize.
final supportInterventionsListProvider =
    FutureProvider<List<SupportInterventionRow>>((ref) async {
  final repo = ref.watch(supportInterventionsRepositoryProvider);
  return repo.listInterventions();
});
