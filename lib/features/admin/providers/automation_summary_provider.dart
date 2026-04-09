import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Souhrn stavu automatizací pro Admin Dashboard KPI.
///
/// PROČ: Manažer potřebuje v jednom pohledu vidět, zda automatizace
/// běží (aktivní pravidla) a zda se hromadí položky ve frontě (čekající/selhání).
class AutomationSummary {
  const AutomationSummary({
    required this.activeRulesCount,
    required this.scheduledQueueCount,
    required this.failedQueueCount,
  });

  /// Počet aktivních pravidel v `automation_rules` (is_active=true).
  final int activeRulesCount;

  /// Počet čekajících zpráv ve frontě (UX značí „scheduled“ = DB status `pending`).
  final int scheduledQueueCount;

  /// Počet selhaných položek ve frontě (`automation_message_queue.status = failed`).
  final int failedQueueCount;
}

/// Riverpod provider pro výpočet [AutomationSummary].
///
/// PROČ: dotazy musí být tenantově izolované – používáme `SupabaseService.safeFrom`
/// s `tenant_id` z [authNotifierProvider].
final automationSummaryProvider =
    AsyncNotifierProvider<AutomationSummaryNotifier, AutomationSummary>(
  AutomationSummaryNotifier.new,
);

class AutomationSummaryNotifier extends AsyncNotifier<AutomationSummary> {
  @override
  Future<AutomationSummary> build() async {
    try {
      final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) {
        return const AutomationSummary(
          activeRulesCount: 0,
          scheduledQueueCount: 0,
          failedQueueCount: 0,
        );
      }

      // PROČ count(CountOption.exact): KPI musí ukazovat přesná čísla,
      // aby manažer mohl rychle vyhodnotit tlak na frontu.
      final activeRulesRes = await SupabaseService.safeFrom(
        'automation_rules',
        tenantId,
      )
          .select('id')
          .eq('is_active', true)
          .count(CountOption.exact);

      final scheduledQueueRes = await SupabaseService.safeFrom(
        'automation_message_queue',
        tenantId,
      )
          .select('id')
          .eq('status', 'pending')
          .count(CountOption.exact);

      final failedQueueRes = await SupabaseService.safeFrom(
        'automation_message_queue',
        tenantId,
      )
          .select('id')
          .eq('status', 'failed')
          .count(CountOption.exact);

      return AutomationSummary(
        activeRulesCount: activeRulesRes.count,
        scheduledQueueCount: scheduledQueueRes.count,
        failedQueueCount: failedQueueRes.count,
      );
    } catch (_) {
      // PROČ rethrow: Riverpod to zobrazí jako `AsyncValue.error`, které UI
      // uživatelům zobrazí bezpečný user-friendly stav (žádný pád).
      rethrow;
    }
  }
}

