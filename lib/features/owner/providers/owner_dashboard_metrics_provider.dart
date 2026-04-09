import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/providers/owner_billing_provider.dart';

/// Souhrnné metriky pro nástěnku majitele (bez nových tabulek).
class OwnerDashboardMetrics {
  const OwnerDashboardMetrics({
    required this.upcomingStaysNext14Days,
    required this.uninvoicedOwnerServicesTotal,
  });

  /// Počet rezervací (ne zrušených) se začátkem v příštích 14 dnech včetně dneška.
  final int upcomingStaysNext14Days;

  /// Součet charged_price u služeb s plátcem majitel, u rezervací jejichž ID ještě nefiguruje ve zmražených snapshotech.
  final double uninvoicedOwnerServicesTotal;
}

/// Vytáhne z [snapshot_data.items] všechna reservation_id pro odfiltrování již uzavřených období.
Set<String> _reservationIdsFromSnapshots(List<BillingSnapshotModel> snapshots) {
  final ids = <String>{};
  for (final s in snapshots) {
    final itemsRaw = s.snapshotData['items'];
    if (itemsRaw is! List) continue;
    for (final item in itemsRaw) {
      if (item is! Map) continue;
      final rid = item['reservation_id']?.toString().trim();
      if (rid != null && rid.isNotEmpty) ids.add(rid);
    }
  }
  return ids;
}

final ownerDashboardMetricsProvider =
    FutureProvider<OwnerDashboardMetrics>((ref) async {
  final apartments = await ref.watch(ownerApartmentsProvider.future);
  final ownedIds = apartments
      .map((a) => a.id)
      .where((id) => id.isNotEmpty)
      .toList();
  if (ownedIds.isEmpty) {
    return const OwnerDashboardMetrics(
      upcomingStaysNext14Days: 0,
      uninvoicedOwnerServicesTotal: 0,
    );
  }

  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    return const OwnerDashboardMetrics(
      upcomingStaysNext14Days: 0,
      uninvoicedOwnerServicesTotal: 0,
    );
  }

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final endWindow = todayDate.add(const Duration(days: 14));
  final startStr =
      '${todayDate.year.toString().padLeft(4, '0')}-${todayDate.month.toString().padLeft(2, '0')}-${todayDate.day.toString().padLeft(2, '0')}';
  final endStr =
      '${endWindow.year.toString().padLeft(4, '0')}-${endWindow.month.toString().padLeft(2, '0')}-${endWindow.day.toString().padLeft(2, '0')}';

  var upcoming = 0;
  try {
    final countRes = await SupabaseService.safeFrom('reservations', tenantId)
        .select('id')
        .inFilter('apartment_id', ownedIds)
        .isFilter('deleted_at', null)
        .neq('status', 'cancelled')
        .gte('start_date', startStr)
        .lte('start_date', endStr)
        .count(CountOption.exact);
    upcoming = countRes.count;
  } catch (e, st) {
    AppLogger.error('ownerDashboardMetricsProvider: počet nadcházejících pobytů selhal', e, st);
    upcoming = 0;
  }

  final snapshots = await ref.watch(ownerBillingSnapshotsProvider.future);
  final lockedReservationIds = _reservationIdsFromSnapshots(snapshots);

  double uninvoiced = 0;
  try {
    final resList = await SupabaseService.safeFrom('reservations', tenantId)
        .select('id')
        .inFilter('apartment_id', ownedIds)
        .isFilter('deleted_at', null)
        .neq('status', 'cancelled');

    final resRows = resList as List? ?? [];
    final reservationIds = <String>[];
    for (final e in resRows) {
      final id = (e as Map)['id']?.toString().trim();
      if (id != null && id.isNotEmpty) reservationIds.add(id);
    }

    if (reservationIds.isEmpty) {
      return OwnerDashboardMetrics(
        upcomingStaysNext14Days: upcoming,
        uninvoicedOwnerServicesTotal: 0,
      );
    }

    final rsRes = await SupabaseService.safeFrom('reservation_services', tenantId)
        .select('charged_price, reservation_id, payer_type')
        .inFilter('reservation_id', reservationIds)
        .eq('payer_type', 'owner');

    final rsRows = rsRes as List? ?? [];
    for (final row in rsRows) {
      final m = Map<String, dynamic>.from(row as Map);
      final rid = (m['reservation_id']?.toString() ?? '').trim();
      if (rid.isEmpty || lockedReservationIds.contains(rid)) continue;
      final cp = m['charged_price'];
      final price = cp is num
          ? cp.toDouble()
          : (double.tryParse(cp?.toString() ?? '') ?? 0.0);
      uninvoiced += price;
    }
  } catch (e, st) {
    AppLogger.error('ownerDashboardMetricsProvider: výpočet nevyfakturovaných služeb selhal', e, st);
    uninvoiced = 0;
  }

  return OwnerDashboardMetrics(
    upcomingStaysNext14Days: upcoming,
    uninvoicedOwnerServicesTotal: uninvoiced,
  );
});
