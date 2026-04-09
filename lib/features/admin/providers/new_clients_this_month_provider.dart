import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// KPI souhrn nových klientů v aktuálním měsíci.
///
/// PROČ: Manažer potřebuje rychle vidět, jestli CRM (a přísun leadů)
/// roste. Proto počítáme nové záznamy v `clients` podle `created_at`
/// a volitelně vracíme breakdown podle `client_type`.
class NewClientsThisMonthSummary {
  const NewClientsThisMonthSummary({
    required this.totalNewClients,
    required this.ownerNewClients,
    required this.externalNewClients,
    required this.agencyNewClients,
    required this.unknownNewClients,
  });

  final int totalNewClients;
  final int ownerNewClients;
  final int externalNewClients;
  final int agencyNewClients;
  final int unknownNewClients;
}

/// Provider pro výpočet [NewClientsThisMonthSummary] pro aktuálního tenanta.
final newClientsThisMonthProvider =
    AsyncNotifierProvider<NewClientsThisMonthNotifier, NewClientsThisMonthSummary>(
  NewClientsThisMonthNotifier.new,
);

class NewClientsThisMonthNotifier
    extends AsyncNotifier<NewClientsThisMonthSummary> {
  @override
  Future<NewClientsThisMonthSummary> build() async {
    try {
      final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) {
        return const NewClientsThisMonthSummary(
          totalNewClients: 0,
          ownerNewClients: 0,
          externalNewClients: 0,
          agencyNewClients: 0,
          unknownNewClients: 0,
        );
      }

      final nowUtc = DateTime.now().toUtc();
      final startUtc = DateTime.utc(nowUtc.year, nowUtc.month, 1);
      final endUtc = DateTime.utc(
        nowUtc.month == 12 ? nowUtc.year + 1 : nowUtc.year,
        nowUtc.month == 12 ? 1 : nowUtc.month + 1,
        1,
      );

      final startIso = startUtc.toIso8601String();
      final endIso = endUtc.toIso8601String();

      // PROČ `deleted_at IS NULL`: soft-delete záznamy nechceme počítat jako „nové“.
      final baseQuery = SupabaseService.safeFrom('clients', tenantId)
          .select('id')
          .gte('created_at', startIso)
          .lt('created_at', endIso)
          .isFilter('deleted_at', null);

      final totalRes = await baseQuery.count(CountOption.exact);
      final total = totalRes.count;

      final ownerRes = await SupabaseService.safeFrom('clients', tenantId)
          .select('id')
          .gte('created_at', startIso)
          .lt('created_at', endIso)
          .isFilter('deleted_at', null)
          .eq('client_type', 'owner')
          .count(CountOption.exact);

      final externalRes = await SupabaseService.safeFrom('clients', tenantId)
          .select('id')
          .gte('created_at', startIso)
          .lt('created_at', endIso)
          .isFilter('deleted_at', null)
          .eq('client_type', 'external')
          .count(CountOption.exact);

      final agencyRes = await SupabaseService.safeFrom('clients', tenantId)
          .select('id')
          .gte('created_at', startIso)
          .lt('created_at', endIso)
          .isFilter('deleted_at', null)
          .eq('client_type', 'agency')
          .count(CountOption.exact);

      final owner = ownerRes.count;
      final external = externalRes.count;
      final agency = agencyRes.count;

      // PROČ unknown = total - (owner+external+agency):
      // v DB může být `client_type` NULL nebo jiná hodnota (např. budoucí typy).
      final unknown = total - (owner + external + agency);

      return NewClientsThisMonthSummary(
        totalNewClients: total,
        ownerNewClients: owner,
        externalNewClients: external,
        agencyNewClients: agency,
        unknownNewClients: unknown > 0 ? unknown : 0,
      );
    } catch (_) {
      // PROČ rethrow: UI má `AsyncValue.when(error: ...)`, takže zobrazíme
      // user-friendly stav místo pádu.
      rethrow;
    }
  }
}

