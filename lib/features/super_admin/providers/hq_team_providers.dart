import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/super_admin/services/hq_staff_contract_repository.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Repozitář smluv HQ – jedna instance pro celou aplikaci.
final hqStaffContractRepositoryProvider =
    Provider<HqStaffContractRepository>((ref) => HqStaffContractRepository());

/// Načte aktuálně platnou smlouvu pro daného člena HQ.
///
/// PROČ: autoDispose – detail pracovníka se po zavření přestane sledovat, uvolní se cache
/// a při příštím otevření se data znovu načtou. Family(profileId) = jeden provider na profil.
final hqStaffActiveContractProvider = FutureProvider.autoDispose
    .family<HqStaffContractRow?, String>((ref, profileId) async {
  if (profileId.trim().isEmpty) return null;
  final repo = ref.watch(hqStaffContractRepositoryProvider);
  return repo.getActiveContractForProfile(profileId);
});

/// Minimální záznam agentury pro záložku Portfolio (Lovec / Farmář).
class HqPortfolioTenant {
  const HqPortfolioTenant({required this.id, required this.name});
  final String id;
  final String name;
}

/// Portfolio člena HQ – agentury, které ulovil (Lovec) a které spravuje (Farmář).
///
/// PROČ: Jeden model pro obě listiny umožňuje v UI zobrazit dvě sekce bez dvou samostatných
/// providerů a zároveň načteme data jedním dotazem (OR na acquired_by / managed_by).
class HqStaffPortfolio {
  const HqStaffPortfolio({
    required this.acquiredByMe,
    required this.managedByMe,
  });

  /// Agentury, které tento profil přivedl (tenants.acquired_by = profileId).
  final List<HqPortfolioTenant> acquiredByMe;
  /// Agentury, které tento profil spravuje (tenants.managed_by = profileId).
  final List<HqPortfolioTenant> managedByMe;
}

/// Načte portfolio daného HQ pracovníka – seznam agentur ulovených a spravovaných.
///
/// PROČ: Jedním dotazem na tenants s OR(acquired_by, managed_by) získáme obě listiny
/// a v Dartu je rozdělíme podle sloupce. autoDispose.family = vázáno na profileId a uvolnění po opuštění obrazovky.
final hqStaffPortfolioProvider = FutureProvider.autoDispose
    .family<HqStaffPortfolio, String>((ref, profileId) async {
  if (profileId.trim().isEmpty) {
    return const HqStaffPortfolio(acquiredByMe: [], managedByMe: []);
  }
  try {
    final res = await SupabaseService.client
        .from('tenants')
        .select('id, name, acquired_by, managed_by')
        .or('acquired_by.eq.$profileId,managed_by.eq.$profileId')
        .filter('deleted_at', 'is', null);

    final list = res as List<dynamic>;
    final acquired = <HqPortfolioTenant>[];
    final managed = <HqPortfolioTenant>[];
    for (final e in list) {
      final map = Map<String, dynamic>.from(e as Map);
      final id = (map['id'] as String?)?.trim() ?? '';
      final name = (map['name'] as String?)?.trim() ?? id;
      if (id.isEmpty) continue;
      final row = HqPortfolioTenant(id: id, name: name);
      final ab = (map['acquired_by'] as String?)?.trim();
      final mb = (map['managed_by'] as String?)?.trim();
      if (ab == profileId) acquired.add(row);
      if (mb == profileId) managed.add(row);
    }
    return HqStaffPortfolio(acquiredByMe: acquired, managedByMe: managed);
  } catch (_) {
    return const HqStaffPortfolio(acquiredByMe: [], managedByMe: []);
  }
});

/// Načte absence (dovolené) pro člena HQ – řádky s tenant_id IS NULL a profile_id = profileId.
///
/// PROČ: HQ člen nemá tenant_id, proto jeho dovolené ukládáme s tenant_id = NULL.
/// Reuse modelu StaffAbsence z admin týmu (stejná struktura staff_absences). autoDispose.family
/// = data se načtou jen pro otevřený detail a po opuštění se zruší.
final hqStaffAbsencesProvider = FutureProvider.autoDispose
    .family<List<StaffAbsence>, String>((ref, profileId) async {
  if (profileId.trim().isEmpty) return [];
  try {
    final res = await SupabaseService.client
        .from('staff_absences')
        .select('id, profile_id, invitation_id, start_date, end_date, reason')
        .eq('profile_id', profileId)
        .filter('tenant_id', 'is', null)
        .order('start_date', ascending: false);

    final list = res as List<dynamic>;
    return list
        .map((e) => StaffAbsence.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (_) {
    return [];
  }
});
