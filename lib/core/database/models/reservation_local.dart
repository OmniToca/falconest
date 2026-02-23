import 'package:isar/isar.dart';

import 'sync_status.dart';

part 'reservation_local.g.dart';

/// Lokální Isar model reprezentující rezervaci (minimální subset pro Worker).
///
/// Používá se pro offline-first update statusu při dokončení Check-in úkolu.
/// [localUpdatedAt] – čas poslední lokální úpravy (Timestamp Merging).
/// [syncStatus] – pending = změna čeká na odeslání do Supabase.
///
@collection
class ReservationLocal {
  /// Automaticky generované Isar ID pro lokální jednoznačnost.
  Id id = Isar.autoIncrement;

  /// UUID záznamu v Supabase. Používá se pro párování při sync.
  String? supabaseId;

  /// ID tenanta – multi-tenant izolace.
  late String tenantId;

  /// Stav rezervace: new, confirmed, checked_in, checked_out, cancelled.
  late String status;

  /// Čas poslední lokální úpravy v UTC. Klíčové pro Timestamp Merging.
  late DateTime localUpdatedAt;

  /// Zda jsou lokální změny již odeslané do Supabase.
  @enumerated
  late SyncStatus syncStatus;

  /// Čas poslední změny – pro sync queue.
  late DateTime lastUpdated;

  ReservationLocal();

  /// Vytvoří ReservationLocal z mapy (např. JSON odpověď ze Supabase).
  factory ReservationLocal.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now().toUtc();
    final idRaw = map['id']?.toString().trim();
    return ReservationLocal()
      ..supabaseId = (idRaw != null && idRaw.isNotEmpty) ? idRaw : null
      ..tenantId = (map['tenant_id']?.toString() ?? '').trim()
      ..status = (map['status']?.toString() ?? 'new').trim()
      ..syncStatus = SyncStatus.synced
      ..localUpdatedAt = now
      ..lastUpdated = now;
  }
}
