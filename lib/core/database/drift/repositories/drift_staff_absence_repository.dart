import 'package:drift/drift.dart';

import 'package:falconest_drift/app_database.dart' as drift_db;

/// Lokální čtení a zápis nepřítomností (`staff_absences`) pro Worker.
///
/// PROČ: Obrazovka „Moje nepřítomnost“ nesmí volat Supabase při každém otevření; data přijdou
/// při worker sync a nové žádosti se zapisují sem před zařazením INSERT mutace.
class DriftStaffAbsenceRepository {
  DriftStaffAbsenceRepository(this._db);

  final drift_db.AppDatabase _db;

  /// Sleduje absence daného pracovníka v tenantu, řazeno od nejnovějšího [startDate].
  ///
  /// PROČ: Stream překreslí UI po synci i po lokálním přidání řádku.
  Stream<List<drift_db.DriftStaffAbsence>> watchForProfile(String tenantId, String profileId) {
    if (tenantId.isEmpty || profileId.isEmpty) {
      return Stream.value(const []);
    }
    return (_db.select(_db.staffAbsences)
          ..where((a) => a.tenantId.equals(tenantId) & a.profileId.equals(profileId))
          ..orderBy([(a) => OrderingTerm.desc(a.startDate)]))
        .watch();
  }

  /// Přepíše lokální řádky podle odpovědi Supabase (full replace pro daný pár tenant+profile).
  ///
  /// PROČ: Stejný vzor jako u výplat – jednoduchá konzistence bez složitého merge UUID.
  Future<void> replaceFromSupabaseForProfile(
    String tenantId,
    String profileId,
    List<dynamic> rawRows,
  ) async {
    if (tenantId.isEmpty || profileId.isEmpty) return;

    await (_db.delete(_db.staffAbsences)
          ..where((a) => a.tenantId.equals(tenantId) & a.profileId.equals(profileId)))
        .go();

    for (final raw in rawRows) {
      final map = raw is Map<String, dynamic> ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final sid = map['id']?.toString().trim();
      if (sid == null || sid.isEmpty) continue;
      final tid = map['tenant_id']?.toString().trim() ?? tenantId;
      final pid = map['profile_id']?.toString().trim() ?? profileId;
      if (pid != profileId || tid != tenantId) continue;

      final start = _parseDate(map['start_date']);
      final end = _parseDate(map['end_date']) ?? start;
      if (start == null) continue;

      final reason = (map['reason']?.toString() ?? '').trim();
      final status = (map['status']?.toString() ?? 'pending').trim();
      final inv = map['invitation_id']?.toString().trim();
      final created = _parseDate(map['created_at']) ?? DateTime.now().toUtc();
      final updated = _parseDate(map['updated_at']) ?? created;

      await _db.into(_db.staffAbsences).insert(
            drift_db.StaffAbsencesCompanion.insert(
              supabaseId: sid,
              tenantId: tid,
              profileId: pid,
              invitationId: Value(inv != null && inv.isNotEmpty ? inv : null),
              startDate: start,
              endDate: end ?? start,
              reason: Value(reason),
              status: Value(status.isEmpty ? 'pending' : status),
              createdAt: created,
              updatedAt: updated,
            ),
          );
    }
  }

  /// Uloží novou žádost o absenci lokálně (okamžitě viditelná v UI) před odesláním INSERT na server.
  ///
  /// PROČ: Offline-first – seznam se aktualizuje z Driftu; [supabaseId] musí být stejné UUID jako v payloadu mutace.
  Future<void> insertPendingAbsence({
    required String supabaseId,
    required String tenantId,
    required String profileId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required String status,
  }) async {
    final now = DateTime.now().toUtc();
    await _db.into(_db.staffAbsences).insert(
          drift_db.StaffAbsencesCompanion.insert(
            supabaseId: supabaseId,
            tenantId: tenantId,
            profileId: profileId,
            invitationId: const Value.absent(),
            startDate: startDate,
            endDate: endDate,
            reason: Value(reason),
            status: Value(status),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc();
    return DateTime.tryParse(v.toString())?.toUtc();
  }
}
