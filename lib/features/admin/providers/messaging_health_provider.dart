import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/platform_messaging_rates_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Souhrn „Zdraví komunikace“ pro Admin Dashboard.
///
/// PROČ: Manažer chce vidět, kolik zpráv se v aktuálním měsíci odeslalo
/// a jaký to má orientační náklad (podle platformních sazeb v DB).
class MessagingHealthSummary {
  const MessagingHealthSummary({
    required this.sentMessagesThisMonth,
    required this.estimatedCostEurThisMonth,
  });

  /// Počet odeslaných zpráv v aktuálním měsíci (součet dle kanálů).
  final int sentMessagesThisMonth;

  /// Odhad nákladů v EUR (součet: sms*price + whatsapp*price + email*price).
  final double estimatedCostEurThisMonth;
}

/// Provider pro načtení [MessagingHealthSummary] pro aktuální tenant.
///
/// Všechny dotazy na data tenanta jdou přes `SupabaseService.safeFrom` kvůli RLS.
final messagingHealthProvider =
    AsyncNotifierProvider<MessagingHealthNotifier, MessagingHealthSummary>(
  MessagingHealthNotifier.new,
);

class MessagingHealthNotifier
    extends AsyncNotifier<MessagingHealthSummary> {
  @override
  Future<MessagingHealthSummary> build() async {
    try {
      final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) {
        return const MessagingHealthSummary(
          sentMessagesThisMonth: 0,
          estimatedCostEurThisMonth: 0,
        );
      }

      final nowUtc = DateTime.now().toUtc();
      final billingMonth =
          '${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}';

      // PROČ `tenant_usage_monthly`: už je agregované per tenant + per channel,
      // takže v dashboardu nezatěžujeme DB složitými agregacemi nad `tenant_message_log`.
      final usageRes = await SupabaseService.safeFrom(
        'tenant_usage_monthly',
        tenantId,
      )
          .select('channel, sent_count')
          .eq('billing_month', billingMonth)
          .inFilter('channel', ['sms', 'whatsapp', 'email']);

      if (usageRes is! List) {
        throw StateError('messaging_health.unexpected_usage_response');
      }

      int smsCount = 0;
      int whatsappCount = 0;
      int emailCount = 0;

      for (final e in usageRes) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);

        final channel = (map['channel'] as String?)?.trim().toLowerCase() ?? '';
        final sentRaw = map['sent_count'];
        final sentCount = sentRaw is int
            ? sentRaw
            : (sentRaw is num ? sentRaw.toInt() : 0);

        if (channel == 'sms') smsCount += sentCount;
        if (channel == 'whatsapp') whatsappCount += sentCount;
        if (channel == 'email') emailCount += sentCount;
      }

      // PROČ sazby bereme z `platform_messaging_rates` (provider s fallbackem):
      // stejně jako Edge `automation-dispatch`, aby odhad odpovídal fakturaci.
      final rates = await ref.watch(platformMessagingRatesProvider.future);

      final estimatedCostEur = smsCount * rates.sms +
          whatsappCount * rates.whatsapp +
          emailCount * rates.email;

      return MessagingHealthSummary(
        sentMessagesThisMonth: smsCount + whatsappCount + emailCount,
        estimatedCostEurThisMonth: estimatedCostEur,
      );
    } catch (_) {
      // PROČ rethrow: Riverpod to promění na `AsyncValue.error`, které UI
      // zobrazí jako uživatelsky přívětivý stav (ne pád).
      rethrow;
    }
  }
}

