import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/billing/billing_task_financials.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';

/// Souhrnné metriky pro nástěnku majitele (bez nových tabulek).
class OwnerDashboardMetrics {
  const OwnerDashboardMetrics({
    required this.upcomingStaysNext14Days,
    required this.uninvoicedOwnerServicesTotal,
  });

  /// Počet rezervací (ne zrušených) se začátkem v příštích 14 dnech včetně dneška.
  final int upcomingStaysNext14Days;

  /// Součet částek u dokončených nevyfakturovaných úkolů (`invoiced_at` IS NULL) s plátcem majitel,
  /// vypočtený stejně jako v Admin „Podklady pro fakturaci“ ([billingChargedPriceAndPayerForTask]).
  /// Stav vyfakturování řeší výhradně sloupec úkolu `invoiced_at` (po uzavření z Adminu), ne agregace snapshotů.
  final double uninvoicedOwnerServicesTotal;
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

  double uninvoiced = 0;
  try {
    final tasksRes = await SupabaseService.safeFrom('tasks', tenantId)
        .select(
          'id, apartment_id, client_id, reservation_id, service_id, metadata',
        )
        .inFilter('apartment_id', ownedIds)
        .eq('status', 'completed')
        .isFilter('invoiced_at', null)
        .isFilter('deleted_at', null)
        .limit(5000);

    final tasksList = (tasksRes as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (tasksList.isEmpty) {
      return OwnerDashboardMetrics(
        upcomingStaysNext14Days: upcoming,
        uninvoicedOwnerServicesTotal: 0,
      );
    }

    final reservationIds = tasksList
        .map((t) => (t['reservation_id'] as String?)?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final billingMaps = await buildBillingReservationServiceMaps(
      reservationIds: reservationIds,
      tenantId: tenantId,
    );

    for (final t in tasksList) {
      final priced = billingChargedPriceAndPayerForTask(t, billingMaps);
      if (priced.payerType != 'owner') continue;
      if (priced.chargedPrice > 0) {
        uninvoiced += priced.chargedPrice;
      }
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
