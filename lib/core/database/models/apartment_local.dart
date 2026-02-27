import 'package:isar/isar.dart';

import 'sync_status.dart';

part 'apartment_local.g.dart';

/// Lokální Isar model reprezentující byt (apartment).
///
/// POZNÁMKA: Po změně tohoto modelu je NUTNÉ spustit `dart run build_runner build`.
///
/// Offline-first: Data se primárně čtou z Isar, na pozadí se synchronizují
/// s Supabase. Pole [supabaseId] slouží ke spárování záznamu s cloudovým
/// záznamem při obousměrné synchronizaci.
///
/// [id] = Isar auto-increment pro lokální identifikaci
/// [supabaseId] = UUID z Supabase pro párování při sync
/// [lastSyncedAt] – kdy byl záznam naposledy stažen z Supabase
/// [localUpdatedAt] – čas poslední lokální úpravy (Timestamp Merging)
///
@collection
class ApartmentLocal {
  /// Automaticky generované Isar ID pro lokální jednoznačnost.
  /// Nikdy se nesynchronizuje do cloudu.
  Id id = Isar.autoIncrement;

  /// UUID záznamu v Supabase. Null = nový záznam ještě neodeslaný.
  /// Používá se pro párování při merge (Timestamp Merging).
  String? supabaseId;

  /// ID tenanta – multi-tenant izolace. Musí odpovídat přihlášenému uživateli.
  late String tenantId;

  /// Název bytu
  late String name;

  /// Adresa bytu (volitelné)
  String? address;

  /// Informace o schránce na klíče (volitelné)
  String? keybox;

  /// Interní kód pro importy a podporu (např. SUN-01). Lidsky čitelný identifikátor.
  /// Mapuje apartments.code.
  String? code;

  /// Poznámky majitele – instrukce pro personál (mapuje apartments.owner_notes)
  String? ownerNotes;

  /// Zda jsou lokální změny již odeslané do Supabase.
  @enumerated
  late SyncStatus syncStatus;

  /// Čas poslední lokální úpravy v UTC. Klíčové pro Timestamp Merging.
  late DateTime localUpdatedAt;

  /// Kdy byl záznam naposledy synchronizován z Supabase. Null = nikdy nestahován.
  DateTime? lastSyncedAt;

  /// Čas poslední změny v UTC. Používá se pro řazení a řešení konfliktů.
  late DateTime lastUpdated;

  /// Implicitní konstruktor – potřebný pro Isar deserializaci a factory.
  ApartmentLocal();

  /// Vytvoří ApartmentLocal z mapy (např. JSON odpověď ze Supabase).
  ///
  /// Klíče: id, tenant_id, name, address, keybox, code, owner_notes.
  /// Pro vložení do Isar použij isar.apartmentLocals.put(obj) – id se přiřadí automaticky.
  factory ApartmentLocal.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now().toUtc();
    final idRaw = map['id']?.toString().trim();
    return ApartmentLocal()
      ..supabaseId = (idRaw != null && idRaw.isNotEmpty) ? idRaw : null
      ..tenantId = (map['tenant_id']?.toString() ?? '').trim()
      ..name = (map['name']?.toString() ?? '').trim()
      ..address = (map['address']?.toString() ?? '').trim().isEmpty
          ? null
          : (map['address']?.toString() ?? '').trim()
      ..keybox = (map['keybox']?.toString() ?? '').trim().isEmpty
          ? null
          : (map['keybox']?.toString() ?? '').trim()
      ..code = (map['code']?.toString() ?? '').trim().isEmpty
          ? null
          : (map['code']?.toString() ?? '').trim()
      ..ownerNotes = (map['owner_notes']?.toString() ?? '').trim().isEmpty
          ? null
          : (map['owner_notes']?.toString() ?? '').trim()
      ..syncStatus = SyncStatus.synced
      ..localUpdatedAt = now
      ..lastSyncedAt = now
      ..lastUpdated = now;
  }
}
