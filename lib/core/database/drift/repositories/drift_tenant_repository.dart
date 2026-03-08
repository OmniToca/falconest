import 'package:drift/drift.dart';
import 'package:falconest_drift/app_database.dart' as db;

/// Drift repozitář pro tenanty – ekvivalent Isar TenantLocal.
///
/// Paralelní implementace pro plný přechod na offline-first relační databázi.
/// Důvod: Isar 3.x na iOS vykazuje nestabilitu. SQLite zajišťuje 100 % běh.
///
/// Worker UI potřebuje měnu tenanta pro formátování hotovosti offline.
/// currentTenantCurrencyProvider čte z tohoto repozitáře.
class DriftTenantRepository {
  DriftTenantRepository(this._db);

  final db.AppDatabase _db;

  /// Načte tenanta podle Supabase UUID. Používá se pro currentTenantCurrencyProvider.
  Future<db.Tenant?> getBySupabaseId(String supabaseId) async {
    if (supabaseId.trim().isEmpty) return null;
    final rows = await (_db.select(_db.tenants)
          ..where((t) => t.supabaseId.equals(supabaseId)))
        .get();
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Uloží nebo aktualizuje tenanta z mapy ze Supabase (sync).
  /// Klíče: id, currency.
  Future<void> upsertFromSupabaseMap(Map<String, dynamic> map) async {
    final tenant = _mapToTenant(map);
    if (tenant == null) return;
    final existing = await (_db.select(_db.tenants)
          ..where((t) => t.supabaseId.equals(tenant.supabaseId)))
        .get();
    if (existing.isNotEmpty) {
      final current = existing.first;
      await _db.update(_db.tenants).replace(
            db.Tenant(
              id: current.id,
              supabaseId: tenant.supabaseId,
              currency: tenant.currency,
            ),
          );
    } else {
      await _db.into(_db.tenants).insert(
            db.TenantsCompanion.insert(
              supabaseId: tenant.supabaseId,
              currency: Value(tenant.currency),
            ),
          );
    }
  }

  static db.Tenant? _mapToTenant(Map<String, dynamic> map) {
    final idRaw = map['id']?.toString().trim();
    if (idRaw == null || idRaw.isEmpty) return null;
    final currRaw = map['currency']?.toString().trim();
    return db.Tenant(
      id: 0,
      supabaseId: idRaw,
      currency: (currRaw != null && currRaw.isNotEmpty)
          ? currRaw.toUpperCase()
          : null,
    );
  }
}
