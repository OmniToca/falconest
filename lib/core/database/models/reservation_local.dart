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

  /// Jméno hosta – pro zobrazení check-in agentům a řidičům (kontakt v terénu).
  String? guestName;

  /// Telefon hosta – pro přímé volání při zpoždění nebo předání (tel: link).
  String? guestPhone;

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
    final gName = (map['guest_name'] as String?)?.trim();
    final gPhone = (map['guest_phone'] as String?)?.trim();
    return ReservationLocal()
      ..supabaseId = (idRaw != null && idRaw.isNotEmpty) ? idRaw : null
      ..tenantId = (map['tenant_id']?.toString() ?? '').trim()
      ..status = (map['status']?.toString() ?? 'new').trim()
      ..guestName = (gName != null && gName.isNotEmpty) ? gName : null
      ..guestPhone = (gPhone != null && gPhone.isNotEmpty) ? gPhone : null
      ..syncStatus = SyncStatus.synced
      ..localUpdatedAt = now
      ..lastUpdated = now;
  }
}
