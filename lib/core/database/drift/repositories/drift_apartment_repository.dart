import 'package:drift/drift.dart';
import 'package:falconest/core/constants/apartment_rental_constants.dart'
    show
        kApartmentRentalModeLongTerm,
        kApartmentRentalModeShortTerm,
        kApartmentRentCollectionModeNotification,
        kApartmentRentCollectionModeTask;
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
              investmentTrackingEnabled: apt.investmentTrackingEnabled,
              rentalMode: apt.rentalMode,
              leaseStartDate: apt.leaseStartDate,
              leaseEndDate: apt.leaseEndDate,
              rentAmount: apt.rentAmount,
              rentDueDay: apt.rentDueDay,
              rentCollectionMode: apt.rentCollectionMode,
              rentTaskAssigneeId: apt.rentTaskAssigneeId,
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
              investmentTrackingEnabled: Value(apt.investmentTrackingEnabled),
              rentalMode: Value(apt.rentalMode),
              leaseStartDate: Value(apt.leaseStartDate),
              leaseEndDate: Value(apt.leaseEndDate),
              rentAmount: Value(apt.rentAmount),
              rentDueDay: Value(apt.rentDueDay),
              rentCollectionMode: Value(apt.rentCollectionMode),
              rentTaskAssigneeId: Value(apt.rentTaskAssigneeId),
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
    final invRaw = map['investment_tracking_enabled'];
    final investmentTracking = invRaw is bool
        ? invRaw
        : (invRaw?.toString().toLowerCase() == 'true');
    final modeRaw = (map['rental_mode']?.toString() ?? '').trim().toLowerCase();
    final rentalMode = modeRaw == kApartmentRentalModeLongTerm
        ? kApartmentRentalModeLongTerm
        : kApartmentRentalModeShortTerm;
    final ra = map['rent_amount'];
    double rentAmount = 0.0;
    if (ra is num) {
      rentAmount = ra.toDouble();
    } else if (ra != null) {
      rentAmount = double.tryParse(ra.toString()) ?? 0.0;
    }
    final rdd = map['rent_due_day'];
    int rentDueDay = 1;
    if (rdd is int) {
      rentDueDay = rdd.clamp(1, 31);
    } else if (rdd is num) {
      rentDueDay = rdd.toInt().clamp(1, 31);
    } else if (rdd != null) {
      rentDueDay = int.tryParse(rdd.toString())?.clamp(1, 31) ?? 1;
    }
    final rcmRaw = (map['rent_collection_mode']?.toString() ?? '').trim().toLowerCase();
    final rentCollectionMode = rcmRaw == kApartmentRentCollectionModeTask
        ? kApartmentRentCollectionModeTask
        : kApartmentRentCollectionModeNotification;
    final rta = map['rent_task_assignee_id']?.toString().trim();
    final rentTaskAssigneeId = (rta == null || rta.isEmpty) ? null : rta;
    DateTime? leaseStart;
    final ls = map['lease_start_date'];
    if (ls != null) {
      if (ls is DateTime) {
        leaseStart = DateTime.utc(ls.year, ls.month, ls.day);
      } else {
        final d = DateTime.tryParse(ls.toString());
        if (d != null) leaseStart = DateTime.utc(d.year, d.month, d.day);
      }
    }
    DateTime? leaseEnd;
    final le = map['lease_end_date'];
    if (le != null) {
      if (le is DateTime) {
        leaseEnd = DateTime.utc(le.year, le.month, le.day);
      } else {
        final d = DateTime.tryParse(le.toString());
        if (d != null) leaseEnd = DateTime.utc(d.year, d.month, d.day);
      }
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
      investmentTrackingEnabled: investmentTracking,
      rentalMode: rentalMode,
      leaseStartDate: leaseStart,
      leaseEndDate: leaseEnd,
      rentAmount: rentAmount,
      rentDueDay: rentDueDay,
      rentCollectionMode: rentCollectionMode,
      rentTaskAssigneeId: rentTaskAssigneeId,
      syncStatus: 0,
      localUpdatedAt: now,
      lastSyncedAt: now,
      lastUpdated: now,
    );
  }
}
