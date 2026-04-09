import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Souhrn selhávajících/zakázaných zpráv pro Admin Dashboard.
///
/// PROČ: Manažer potřebuje rychle odlišit:
/// - tlak ve frontě (opakované pokusy/selhání dispatch),
/// - selhání v audit logu za poslední období (historický signál).
class MessagingFailuresSummary {
  const MessagingFailuresSummary({
    required this.failedQueueOrCancelledCount,
    required this.failedLogCountLastDays,
    required this.lastDays,
  });

  /// Počet zpráv ve frontě (`automation_message_queue`) se stavem `failed` nebo `cancelled`.
  final int failedQueueOrCancelledCount;

  /// Počet zpráv v logu (`tenant_message_log`) se stavem `failed_at_provider` / `failed`
  /// za posledních [lastDays] dní.
  final int failedLogCountLastDays;

  /// Kolik dní používáme pro filtr logu.
  final int lastDays;
}

/// Provider pro načtení [MessagingFailuresSummary] pro aktuální tenant.
///
/// - fronta: `automation_message_queue` (`status in (failed, cancelled)`)
/// - log: `tenant_message_log` (`status in (failed_at_provider, failed)` + `sent_at` filtr)
///
/// Vše tenantově izolujeme přes `SupabaseService.safeFrom`.
final messagingFailuresProvider =
    AsyncNotifierProvider<MessagingFailuresNotifier, MessagingFailuresSummary>(
  MessagingFailuresNotifier.new,
);

class MessagingFailuresNotifier
    extends AsyncNotifier<MessagingFailuresSummary> {
  @override
  Future<MessagingFailuresSummary> build() async {
    try {
      final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) {
        return const MessagingFailuresSummary(
          failedQueueOrCancelledCount: 0,
          failedLogCountLastDays: 0,
          lastDays: 7,
        );
      }

      const lastDays = 7;
      final nowUtc = DateTime.now().toUtc();
      final sinceIso = nowUtc
          .subtract(const Duration(days: lastDays))
          .toIso8601String();

      // PROČ count(CountOption.exact): KPI musí odpovídat realitě v UI,
      // jinak se manažeři budou dívat na nesprávné číslo.
      final failedQueueRes = await SupabaseService.safeFrom(
        'automation_message_queue',
        tenantId,
      )
          .select('id')
          .inFilter('status', ['failed', 'cancelled'])
          .count(CountOption.exact);

      final failedLogRes = await SupabaseService.safeFrom(
        'tenant_message_log',
        tenantId,
      )
          .select('id')
          .inFilter('status', ['failed_at_provider', 'failed'])
          .gte('sent_at', sinceIso)
          .count(CountOption.exact);

      return MessagingFailuresSummary(
        failedQueueOrCancelledCount: failedQueueRes.count,
        failedLogCountLastDays: failedLogRes.count,
        lastDays: lastDays,
      );
    } catch (_) {
      // PROČ rethrow: Riverpod to promění na error state.
      rethrow;
    }
  }
}

