import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/automation/tenant_message_log_row.dart';

import 'automation_log_repository.dart';

/// Provider pro načtení historie automatizovaných odeslaných zpráv.
///
/// Načítá pouze posledních ~100 záznamů, aby UI zůstalo rychlé.
final automationLogProvider = AsyncNotifierProvider<AutomationLogNotifier, List<TenantMessageLogRow>>(
  AutomationLogNotifier.new,
);

class AutomationLogNotifier extends AsyncNotifier<List<TenantMessageLogRow>> {
  @override
  Future<List<TenantMessageLogRow>> build() async {
    final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return [];
    return AutomationLogRepository.fetchRecent(tenantId: tenantId);
  }
}

/// Historie odeslaných/příchozích zpráv pro jednu rezervaci (admin detail).
///
/// PROČ: Načítá se jen při otevření záložky; invalidace při přepnutí rezervace přes `family`.
final reservationMessageLogProvider =
    FutureProvider.family<List<TenantMessageLogRow>, String>((ref, reservationId) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty || reservationId.isEmpty) return [];
  return AutomationLogRepository.fetchForReservation(
    tenantId: tenantId,
    reservationId: reservationId,
  );
});

