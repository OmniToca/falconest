import 'package:drift/drift.dart';
import 'package:falconest_drift/app_database.dart' as db;

/// Drift repozitář pro byty – ekvivalent Isar ApartmentLocal.
///
/// Paralelní implementace pro plný přechod na offline-first relační databázi.
/// Důvod: Isar 3.x na iOS vykazuje nestabilitu ("Collection id is invalid").
/// SQLite (Drift) zajišťuje 100 % spolehlivý běh na všech platformách.
///
/// Zrcadlí operace: lookup podle supabaseId, upsert ze Supabase mapy.
class DriftApartmentRepository {
  DriftApartmentRepository(this._db);

  final db.AppDatabase _db;

  /// Načte byt podle Supabase UUID. Používá se pro zobrazení jména/adresy u úkolů.
  Future<db.Apartment?> getBySupabaseId(String supabaseId) async {
    if (supabaseId.trim().isEmpty) return null;
    final rows = await (_db.select(_db.apartments)
          ..where((t) => t.supabaseId.equals(supabaseId)))
        .get();
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Uloží nebo aktualizuje byt z mapy ze Supabase (sync).
  /// Klíče: id, tenant_id, name, address, keybox, code, owner_notes.
  Future<void> upsertFromSupabaseMap(Map<String, dynamic> map) async {
    final apt = _mapToApartment(map);
    if (apt == null) return;
    final existing = await (_db.select(_db.apartments)
          ..where((t) => t.supabaseId.equals(apt.supabaseId ?? '')))
        .get();
    final now = DateTime.now().toUtc();
    if (existing.isNotEmpty) {
      final current = existing.first;
      await _db.update(_db.apartments).replace(
            db.Apartment(
              id: current.id,
              supabaseId: apt.supabaseId,
              tenantId: apt.tenantId,
              name: apt.name,
              address: apt.address,
              keybox: apt.keybox,
              code: apt.code,
              ownerNotes: apt.ownerNotes,
              checkInTime: apt.checkInTime,
              checkOutTime: apt.checkOutTime,
              zoneId: apt.zoneId,
              parkingInstructions: apt.parkingInstructions,
              syncStatus: 0,
              localUpdatedAt: now,
              lastSyncedAt: now,
              lastUpdated: now,
            ),
          );
    } else {
      await _db.into(_db.apartments).insert(
            db.ApartmentsCompanion.insert(
              supabaseId: Value(apt.supabaseId),
              tenantId: apt.tenantId,
              name: Value(apt.name),
              address: Value(apt.address),
              keybox: Value(apt.keybox),
              code: Value(apt.code),
              ownerNotes: Value(apt.ownerNotes),
              checkInTime: Value(apt.checkInTime),
              checkOutTime: Value(apt.checkOutTime),
              zoneId: Value(apt.zoneId),
              parkingInstructions: Value(apt.parkingInstructions),
              syncStatus: const Value(0),
              localUpdatedAt: now,
              lastSyncedAt: Value(now),
              lastUpdated: now,
            ),
          );
    }
  }

  static db.Apartment? _mapToApartment(Map<String, dynamic> map) {
    final idRaw = map['id']?.toString().trim();
    if (idRaw == null || idRaw.isEmpty) return null;
    final tenantId = (map['tenant_id']?.toString() ?? '').trim();
    if (tenantId.isEmpty) return null;
    final now = DateTime.now().toUtc();
    String? opt(String key) {
      final v = map[key]?.toString().trim();
      return (v == null || v.isEmpty) ? null : v;
    }
    return db.Apartment(
      id: 0,
      supabaseId: idRaw,
      tenantId: tenantId,
      name: (map['name']?.toString() ?? '').trim(),
      address: opt('address'),
      keybox: opt('keybox'),
      code: opt('code'),
      ownerNotes: opt('owner_notes'),
      // Fáze 2: časy a zóna z Supabase pro worker kontext offline.
      checkInTime: opt('check_in_time'),
      checkOutTime: opt('check_out_time'),
      zoneId: () {
        final z = map['zone_id'];
        if (z == null) return null;
        final s = z.toString().trim();
        return s.isEmpty ? null : s;
      }(),
      // Parkování: může být delší text – prázdný řetězec ukládáme jako null.
      parkingInstructions: () {
        final v = map['parking_instructions'];
        if (v == null) return null;
        final t = v.toString();
        return t.trim().isEmpty ? null : t;
      }(),
      syncStatus: 0,
      localUpdatedAt: now,
      lastSyncedAt: now,
      lastUpdated: now,
    );
  }
}
