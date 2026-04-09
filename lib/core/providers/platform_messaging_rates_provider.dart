import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Globální jednotkové ceny zpráv v EUR (tabulka `platform_messaging_rates`).
///
/// PROČ: Stejný zdroj pravdy jako Edge `automation-dispatch` – Super-Admin billing a další
/// obrazovky nesmí duplikovat natvrdo konstanty. Při chybě dotazu vrátíme bezpečný fallback.
class PlatformMessagingRates {
  const PlatformMessagingRates({
    required this.sms,
    required this.whatsapp,
    required this.email,
  });

  final double sms;
  final double whatsapp;
  final double email;
}

/// Výchozí hodnoty shodné se seedem migrace – záchrana při výpadku sítě / prázdné tabulce.
const PlatformMessagingRates _fallbackRates = PlatformMessagingRates(
  sms: 0.05,
  whatsapp: 0.08,
  email: 0.02,
);

/// Načte aktuální tarif: pro každý kanál řádek s nejnovějším `valid_from` ≤ nyní.
final platformMessagingRatesProvider = FutureProvider<PlatformMessagingRates>((ref) async {
  try {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final res = await SupabaseService.client
        .from('platform_messaging_rates')
        .select('channel, price_eur, valid_from')
        .lte('valid_from', nowIso);

    final list = res as List<dynamic>;
    final best = <String, ({double p, int t})>{};

    for (final e in list) {
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final ch = (map['channel'] as String?)?.trim() ?? '';
      if (ch != 'sms' && ch != 'whatsapp' && ch != 'email') continue;
      final vf = map['valid_from'];
      final tMs = vf is String ? DateTime.tryParse(vf)?.millisecondsSinceEpoch ?? 0 : 0;
      final raw = map['price_eur'];
      final p = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? double.nan;
      if (!p.isFinite) continue;
      final prev = best[ch];
      if (prev == null || tMs > prev.t) {
        best[ch] = (p: p, t: tMs);
      }
    }

    return PlatformMessagingRates(
      sms: best['sms']?.p ?? _fallbackRates.sms,
      whatsapp: best['whatsapp']?.p ?? _fallbackRates.whatsapp,
      email: best['email']?.p ?? _fallbackRates.email,
    );
  } catch (e, st) {
    AppLogger.error('platformMessagingRatesProvider: načtení platform_messaging_rates selhalo, použit fallback', e, st);
    return _fallbackRates;
  }
});
