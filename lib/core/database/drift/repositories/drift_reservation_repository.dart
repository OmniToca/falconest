import 'package:drift/drift.dart';
import 'package:falconest_drift/app_database.dart' as db;

/// Drift repozitář pro rezervace – ekvivalent Isar ReservationLocal.
///
/// Paralelní implementace pro plný přechod na offline-first relační databázi.
/// Důvod: Isar 3.x na iOS vykazuje nestabilitu. SQLite zajišťuje 100 % běh.
///
/// Minimální subset pro Worker: guest_name, guest_phone pro check-in,
/// update statusu při dokončení Check-in úkolu.
/// Fáze 2: [specialRequests] pro zobrazení požadavků hosta offline.
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
            specialRequests: current.specialRequests,
            guestLanguage: current.guestLanguage,
            startDate: current.startDate,
            endDate: current.endDate,
            localUpdatedAt: now,
            // PROČ: Zachovat poslední známé serverové updated_at – Timestamp Merging při pushi
            // porovnává ho s aktuálním řádkem na Supabase; nesmí se resetovat při lokální změně statusu.
            lastSyncedAt: current.lastSyncedAt,
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
              specialRequests: res.specialRequests,
              guestLanguage: res.guestLanguage,
              startDate: res.startDate,
              endDate: res.endDate,
              localUpdatedAt: now,
              lastSyncedAt: res.lastSyncedAt,
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
              specialRequests: Value(res.specialRequests),
              guestLanguage: Value(res.guestLanguage),
              startDate: Value(res.startDate),
              endDate: Value(res.endDate),
              localUpdatedAt: now,
              lastSyncedAt: Value(res.lastSyncedAt),
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
  ///
  /// Pozn.: Preferuj [applyReservationAfterStatusPush], které po Timestamp Merging zapíše
  /// i aktuální snapshot polí ze serveru (kromě statusu z terénu).
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
            specialRequests: res.specialRequests,
            guestLanguage: res.guestLanguage,
            startDate: res.startDate,
            endDate: res.endDate,
            localUpdatedAt: now,
            lastSyncedAt: now,
            syncStatus: 0, // synced
            lastUpdated: now,
          ),
        );
  }

  /// Po úspěšném pushi statusu: Drift = snapshot ze Supabase + status z pracovníka v terénu.
  ///
  /// PROČ Timestamp merging / Smart merge: Do Postgresu posíláme jen `status` z lokálu, ale
  /// lokální řádek může stále obsahovat staré guest_name / termíny z doby před adminovou úpravou.
  /// Tímto přepíšeme Drift daty ze [serverSnapshot] a ponecháme [statusFromWorker], aby UI
  /// odpovídalo pravdě na serveru kromě záměrné terénní změny stavu.
  Future<void> applyReservationAfterStatusPush({
    required int localDriftId,
    required Map<String, dynamic> serverSnapshot,
    required String statusFromWorker,
  }) async {
    final base = _mapToReservation(serverSnapshot);
    if (base == null) return;
    final now = DateTime.now().toUtc();
    await _db.update(_db.reservations).replace(
          db.Reservation(
            id: localDriftId,
            supabaseId: base.supabaseId,
            tenantId: base.tenantId,
            status: statusFromWorker,
            guestName: base.guestName,
            guestPhone: base.guestPhone,
            referenceNumber: base.referenceNumber,
            specialRequests: base.specialRequests,
            guestLanguage: base.guestLanguage,
            startDate: base.startDate,
            endDate: base.endDate,
            localUpdatedAt: now,
            lastSyncedAt: now,
            syncStatus: 0,
            lastUpdated: now,
          ),
        );
  }

  /// Smaže lokální řádek rezervace (např. záznam na serveru už neexistuje – pending push nemá cíl).
  Future<void> deleteLocalReservationByDriftId(int localId) async {
    await (_db.delete(_db.reservations)..where((t) => t.id.equals(localId))).go();
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

    // Fáze 2: special_requests může být delší text – ukládáme celý řetězec.
    final sr = map['special_requests'];
    String? specialRequests;
    if (sr != null) {
      final t = sr.toString().trim();
      specialRequests = t.isEmpty ? null : t;
    }

    return db.Reservation(
      id: 0,
      supabaseId: idRaw,
      tenantId: tenantId,
      status: (map['status']?.toString() ?? 'new').trim(),
      guestName: opt('guest_name'),
      guestPhone: opt('guest_phone'),
      referenceNumber: opt('reference_number'),
      specialRequests: specialRequests,
      guestLanguage: opt('guest_language'),
      startDate: _parseOptionalDateTime(map['start_date']),
      endDate: _parseOptionalDateTime(map['end_date']),
      localUpdatedAt: DateTime.now().toUtc(),
      lastSyncedAt: _parseOptionalDateTime(map['updated_at']),
      syncStatus: 0,
      lastUpdated: DateTime.now().toUtc(),
    );
  }

  /// PostgreSQL `date` / ISO řetězec → UTC (datum bez času jako půlnoc UTC).
  static DateTime? _parseOptionalDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final parsed = DateTime.tryParse(s);
    if (parsed != null) return parsed.toUtc();
    final head = s.split('T').first;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(head);
    if (m != null) {
      final y = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final d = int.tryParse(m.group(3)!);
      if (y != null && mo != null && d != null) {
        return DateTime.utc(y, mo, d);
      }
    }
    return null;
  }

}
