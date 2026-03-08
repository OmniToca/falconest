import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/super_admin/providers/all_tenants_provider.dart';
import 'package:falconest/features/super_admin/providers/hq_staff_provider.dart';
import 'package:falconest/features/super_admin/providers/support_interventions_provider.dart';
import 'package:falconest/features/super_admin/services/agency_management_settlements_repository.dart';

/// Repozitář provizí (agency_management_settlements).
final agencyManagementSettlementsRepositoryProvider =
    Provider<AgencyManagementSettlementsRepository>((ref) => AgencyManagementSettlementsRepository());

/// Data pro jeden řádek (Lovec nebo Farmář) na kartě agentury – odpracovaný čas + již schválená provize.
///
/// PROČ: UI zobrazuje jméno, souhrn zásahů (počet + celkový čas) a umožňuje zadat částku a schválit.
/// Provize se nezapočítávají automaticky – Super-Admin rozhodne na základě výkazů práce.
class RoleSettlementInfo {
  const RoleSettlementInfo({
    required this.profileId,
    required this.profileName,
    required this.interventionsCount,
    required this.totalMinutes,
    this.approvedAmount,
    this.settlementStatus,
    this.settlementId,
  });

  final String profileId;
  final String profileName;
  final int interventionsCount;
  final int totalMinutes;
  /// Už schválená částka (€) – null = zatím neuloženo.
  final num? approvedAmount;
  final String? settlementStatus;
  final String? settlementId;
}

/// Jedna karta agentury na obrazovce Zúčtování odměn – název + Lovec + Farmář.
class TenantSettlementCard {
  const TenantSettlementCard({
    required this.tenantId,
    required this.tenantName,
    this.hunter,
    this.farmer,
  });

  final String tenantId;
  final String tenantName;
  final RoleSettlementInfo? hunter;
  final RoleSettlementInfo? farmer;
}

/// Agregační provider: spojí tenanty (s Lovcem/Farmářem), výkazy práce za měsíc a uložené provize.
///
/// PROČ: Na jedné obrazovce Super-Admin vidí agentury, kdo je Lovce/Farmář, kolik u nich
/// odpracovali (zásahy + čas) a může ručně zadat a schválit provizi. Žádná plná automatizace –
/// provize se zadávají ručně, aby bylo možné zohlednit reálný přínos a zabránit podvodům.
///
/// Přidáno autoDispose pro uvolnění paměti po zavření modálu zúčtování, prevence memory leaků
/// a hromadění starých dat (P2 audit fix).
final monthlyAgencySettlementsProvider =
    FutureProvider.autoDispose.family<List<TenantSettlementCard>, DateTime>((ref, month) async {
  final repo = ref.watch(agencyManagementSettlementsRepositoryProvider);
  final supportRepo = ref.read(supportInterventionsRepositoryProvider);
  final tenants = await ref.read(allTenantsProvider.future);
  final staff = await ref.read(hqStaffProvider.future);
  final periodStart = DateTime.utc(month.year, month.month, 1);
  final periodEnd = month.month == 12
      ? DateTime.utc(month.year + 1, 1, 1)
      : DateTime.utc(month.year, month.month + 1, 1);

  final interventions = await supportRepo.listInterventionsInPeriod(periodStart, periodEnd);
  final settlements = await repo.getSettlementsForPeriod(periodStart);

  final idToName = <String, String>{};
  for (final s in staff) {
    idToName[s.id] = s.displayName;
  }

  final cards = <TenantSettlementCard>[];
  for (final t in tenants) {
    if ((t.acquiredBy == null || t.acquiredBy!.isEmpty) &&
        (t.managedBy == null || t.managedBy!.isEmpty)) continue;

    RoleSettlementInfo? hunter;
    if (t.acquiredBy != null && t.acquiredBy!.trim().isNotEmpty) {
      final pid = t.acquiredBy!.trim();
      final forTenant = interventions.where((i) => i.profileId == pid && i.tenantId == t.id).toList();
      final count = forTenant.length;
      final now = DateTime.now().toUtc();
      var minutes = 0;
      for (final i in forTenant) minutes += i.durationMinutes(now);
      final hunterSett = settlements
          .where((s) => s.profileId == pid && s.tenantId == t.id && s.roleType == 'hunter')
          .toList();
      final sett = hunterSett.isNotEmpty ? hunterSett.first : null;
      hunter = RoleSettlementInfo(
        profileId: pid,
        profileName: idToName[pid] ?? pid,
        interventionsCount: count,
        totalMinutes: minutes,
        approvedAmount: sett?.amount,
        settlementStatus: sett?.status,
        settlementId: sett?.id,
      );
    }

    RoleSettlementInfo? farmer;
    if (t.managedBy != null && t.managedBy!.trim().isNotEmpty) {
      final pid = t.managedBy!.trim();
      final forTenant = interventions.where((i) => i.profileId == pid && i.tenantId == t.id).toList();
      final count = forTenant.length;
      final now = DateTime.now().toUtc();
      var minutes = 0;
      for (final i in forTenant) minutes += i.durationMinutes(now);
      final farmerSett = settlements
          .where((s) => s.profileId == pid && s.tenantId == t.id && s.roleType == 'farmer')
          .toList();
      final sett = farmerSett.isNotEmpty ? farmerSett.first : null;
      farmer = RoleSettlementInfo(
        profileId: pid,
        profileName: idToName[pid] ?? pid,
        interventionsCount: count,
        totalMinutes: minutes,
        approvedAmount: sett?.amount,
        settlementStatus: sett?.status,
        settlementId: sett?.id,
      );
    }

    cards.add(TenantSettlementCard(
      tenantId: t.id,
      tenantName: t.name,
      hunter: hunter,
      farmer: farmer,
    ));
  }
  cards.sort((a, b) => a.tenantName.compareTo(b.tenantName));
  return cards;
});
