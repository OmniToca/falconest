import 'package:drift/drift.dart';
import 'package:falconest_drift/app_database.dart' as db;

/// Drift repozitář pro klienty – ekvivalent Isar ClientLocal.
///
/// Paralelní implementace pro plný přechod na offline-first relační databázi.
/// Důvod: Isar 3.x na iOS vykazuje nestabilitu. SQLite zajišťuje 100 % běh.
///
/// Minimální subset pro Worker: externí úkoly (transfer) mají client_id,
/// pro offline zobrazení jména/telefonu řidiči.
class DriftClientRepository {
  DriftClientRepository(this._db);

  final db.AppDatabase _db;

  /// Načte klienta podle tenant_id a supabaseId.
  Future<db.Client?> getBySupabaseId(String tenantId, String supabaseId) async {
    if (supabaseId.trim().isEmpty || tenantId.trim().isEmpty) return null;
    final rows = await (_db.select(_db.clients)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.supabaseId.equals(supabaseId)))
        .get();
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Uloží nebo aktualizuje klienta z mapy ze Supabase (sync).
  Future<void> upsertFromSupabaseMap(Map<String, dynamic> map) async {
    final client = _mapToClient(map);
    if (client == null) return;
    final existing = await (_db.select(_db.clients)
          ..where((t) =>
              t.tenantId.equals(client.tenantId) &
              t.supabaseId.equals(client.supabaseId ?? '')))
        .get();
    if (existing.isNotEmpty) {
      final current = existing.first;
      await _db.update(_db.clients).replace(
            db.Client(
              id: current.id,
              supabaseId: client.supabaseId,
              tenantId: client.tenantId,
              name: client.name,
              phone: client.phone,
            ),
          );
    } else {
      await _db.into(_db.clients).insert(
            db.ClientsCompanion.insert(
              supabaseId: Value(client.supabaseId),
              tenantId: client.tenantId,
              name: Value(client.name),
              phone: Value(client.phone),
            ),
          );
    }
  }

  /// Mapuje řádek ze Supabase na Drift Client.
  ///
  /// PROČ jen subset: Drift Clients slouží Workeru pro offline zobrazení jména/telefonu
  /// u externích úkolů. Sloupce client_type, agency_id, email nejsou v Drift schématu –
  /// mapování je ignoruje, Supabase může posílat libovolné klíče bez havárie.
  static db.Client? _mapToClient(Map<String, dynamic> map) {
    final idRaw = map['id']?.toString().trim();
    if (idRaw == null || idRaw.isEmpty) return null;
    final tenantId = (map['tenant_id']?.toString() ?? '').trim();
    if (tenantId.isEmpty) return null;
    String? opt(String key) {
      final v = map[key]?.toString().trim();
      return (v == null || v.isEmpty) ? null : v;
    }
    return db.Client(
      id: 0,
      supabaseId: idRaw,
      tenantId: tenantId,
      name: (map['name']?.toString() ?? '').trim(),
      phone: opt('phone'),
    );
  }
}
