import 'package:drift/drift.dart';
import 'package:falconest_drift/app_database.dart' as db;

/// Drift repozitář pro rezervace – ekvivalent Isar ReservationLocal.
///
/// Paralelní implementace pro plný přechod na offline-first relační databázi.
/// Důvod: Isar 3.x na iOS vykazuje nestabilitu. SQLite zajišťuje 100 % běh.
///
/// Minimální subset pro Worker: guest_name, guest_phone pro check-in,
/// update statusu při dokončení Check-in úkolu.
class DriftReservationRepository {
  DriftReservationRepository(this._db);

  final db.AppDatabase _db;

  /// Načte rezervaci podle tenant_id a supabaseId.
  Future<db.Reservation?> getBySupabaseId(
      String tenantId, String supabaseId) async {
    if (supabaseId.trim().isEmpty || tenantId.trim().isEmpty) return null;
    final rows = await (_db.select(_db.reservations)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.supabaseId.equals(supabaseId)))
        .get();
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Aktualizuje status rezervace (např. checked_in při Check-in).
  /// PROČ: TaskRepositoryMobile volá reservation put po změně statusu.
  Future<void> updateStatus(String tenantId, String supabaseId, String status) async {
    final rows = await (_db.select(_db.reservations)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.supabaseId.equals(supabaseId)))
        .get();
    if (rows.isEmpty) return;
    final current = rows.first;
    final now = DateTime.now().toUtc();
    await _db.update(_db.reservations).replace(
          db.Reservation(
            id: current.id,
            supabaseId: current.supabaseId,
            tenantId: current.tenantId,
            status: status,
            guestName: current.guestName,
            guestPhone: current.guestPhone,
            referenceNumber: current.referenceNumber,
            localUpdatedAt: now,
            syncStatus: 1, // pending – čeká na odeslání
            lastUpdated: now,
          ),
        );
  }

  /// Uloží nebo aktualizuje rezervaci z mapy ze Supabase (sync).
  Future<void> upsertFromSupabaseMap(Map<String, dynamic> map) async {
    final res = _mapToReservation(map);
    if (res == null) return;
    final existing = await (_db.select(_db.reservations)
          ..where((t) =>
              t.tenantId.equals(res.tenantId) &
              t.supabaseId.equals(res.supabaseId ?? '')))
        .get();
    final now = DateTime.now().toUtc();
    if (existing.isNotEmpty) {
      final current = existing.first;
      if (current.syncStatus == 1) return; // pending – nepřepisovat
      await _db.update(_db.reservations).replace(
            db.Reservation(
              id: current.id,
              supabaseId: res.supabaseId,
              tenantId: res.tenantId,
              status: res.status,
              guestName: res.guestName,
              guestPhone: res.guestPhone,
              referenceNumber: res.referenceNumber,
              localUpdatedAt: now,
              syncStatus: 0,
              lastUpdated: now,
            ),
          );
    } else {
      await _db.into(_db.reservations).insert(
            db.ReservationsCompanion.insert(
              supabaseId: Value(res.supabaseId),
              tenantId: res.tenantId,
              status: Value(res.status),
              guestName: Value(res.guestName),
              guestPhone: Value(res.guestPhone),
              referenceNumber: Value(res.referenceNumber),
              localUpdatedAt: now,
              syncStatus: const Value(0),
              lastUpdated: now,
            ),
          );
    }
  }

  /// Načte rezervace se syncStatus=pending pro push na Supabase (WorkerSyncService).
  Future<List<db.Reservation>> getPendingReservations(String tenantId) async {
    return (_db.select(_db.reservations)
          ..where((t) =>
              t.tenantId.equals(tenantId) & t.syncStatus.equals(1)))
        .get();
  }

  /// Označí rezervaci jako synchronizovanou po úspěšném push na Supabase.
  Future<void> markReservationSynced(db.Reservation res) async {
    final now = DateTime.now().toUtc();
    await _db.update(_db.reservations).replace(
          db.Reservation(
            id: res.id,
            supabaseId: res.supabaseId,
            tenantId: res.tenantId,
            status: res.status,
            guestName: res.guestName,
            guestPhone: res.guestPhone,
            referenceNumber: res.referenceNumber,
            localUpdatedAt: now,
            syncStatus: 0, // synced
            lastUpdated: now,
          ),
        );
  }

  static db.Reservation? _mapToReservation(Map<String, dynamic> map) {
    final idRaw = map['id']?.toString().trim();
    if (idRaw == null || idRaw.isEmpty) return null;
    final tenantId = (map['tenant_id']?.toString() ?? '').trim();
    if (tenantId.isEmpty) return null;
    String? opt(String key) {
      final v = map[key]?.toString().trim();
      return (v == null || v.isEmpty) ? null : v;
    }
    return db.Reservation(
      id: 0,
      supabaseId: idRaw,
      tenantId: tenantId,
      status: (map['status']?.toString() ?? 'new').trim(),
      guestName: opt('guest_name'),
      guestPhone: opt('guest_phone'),
      referenceNumber: opt('reference_number'),
      localUpdatedAt: DateTime.now().toUtc(),
      syncStatus: 0,
      lastUpdated: DateTime.now().toUtc(),
    );
  }
}
