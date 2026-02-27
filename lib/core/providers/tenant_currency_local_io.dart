/// IO implementace – načtení měny tenanta z Isaru (mobil/desktop).
///
/// Tento soubor se kompiluje pouze pro dart:io. Obsahuje Isar – na webu se nekompiluje.
import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/database/models/tenant_local.dart';

/// Načte měnu tenanta z TenantLocal v Isaru.
/// Vrací null, pokud záznam neexistuje nebo nemá currency.
Future<String?> getTenantCurrencyFromLocal(String tenantId) async {
  if (tenantId.isEmpty) return null;
  try {
    final isar = IsarService.instance;
    final tenant = await isar.tenantLocals.getBySupabaseId(tenantId);
    if (tenant?.currency != null && tenant!.currency!.trim().isNotEmpty) {
      return tenant.currency!.trim().toUpperCase();
    }
  } on StateError {
    // Isar není inicializován.
  } catch (_) {}
  return null;
}
