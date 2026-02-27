import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/tenant_currency_local_stub.dart'
    if (dart.library.io) 'package:falconest/core/providers/tenant_currency_local_io.dart' as tenant_currency_local;
import 'package:falconest/core/services/supabase_service.dart';

/// Načte výchozí měnu aktuálního tenanta (agentury).
///
/// OFFLINE-FIRST: Na mobilu (dart:io) nejprve čte z TenantLocal v Isaru – WorkerSyncService
/// při synchronizaci ukládá tenants (id, currency) do Isaru. Tím se vyhne fallbacku na
/// profiles.preferred_currency a Worker UI zobrazí správnou měnu firmy i bez signálu.
///
/// KROK 1: Mobil – Isar (přes tenant_currency_local, podmíněný import)
/// KROK 2: Lokální data nemá nebo web – Supabase
///
/// Null = tenant nemá měnu nastavenou. Používá se spolu s profiles.preferred_currency
/// jako fallback pro formátování částek.
///
/// POZNÁMKA: Tento soubor je 100% web-safe – neobsahuje žádný import Isaru.
final currentTenantCurrencyProvider = FutureProvider<String?>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return null;

  // KROK 1: Mobil – zkus načíst z Isaru (pouze dart:io, web používá stub který vrací null).
  final fromLocal = await tenant_currency_local.getTenantCurrencyFromLocal(tenantId);
  if (fromLocal != null && fromLocal.trim().isNotEmpty) {
    return fromLocal.trim().toUpperCase();
  }

  // KROK 2: Lokální data nemá nebo web – dotaz do Supabase.
  try {
    final res = await SupabaseService.client
        .from('tenants')
        .select('currency')
        .eq('id', tenantId)
        .maybeSingle();
    if (res != null) {
      final v = res['currency'] as String?;
      if (v != null && v.trim().isNotEmpty) {
        return v.trim().toUpperCase();
      }
    }
  } catch (_) {}
  return null;
});
