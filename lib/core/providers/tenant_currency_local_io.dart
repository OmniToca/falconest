/// IO implementace – načtení měny tenanta z Drift (mobil/desktop).
///
/// Isar odstraněn – Drift (SQLite) zajišťuje stabilitu na iOS.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Načte měnu tenanta z Drift databáze.
/// Vrací null, pokud záznam neexistuje nebo nemá currency.
Future<String?> getTenantCurrencyFromLocal(Ref ref, String tenantId) async {
  if (tenantId.isEmpty) return null;
  try {
    final repo = ref.read(driftTenantRepositoryProvider);
    final tenant = await repo.getBySupabaseId(tenantId);
    if (tenant?.currency != null && tenant!.currency!.trim().isNotEmpty) {
      return tenant.currency!.trim().toUpperCase();
    }
  } catch (e, st) {
    AppLogger.error('tenant_currency_local_io: načtení měny tenanta z Drift selhalo', e, st);
  }
  return null;
}
