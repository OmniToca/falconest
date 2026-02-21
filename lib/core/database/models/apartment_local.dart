import 'package:isar/isar.dart';

import 'sync_status.dart';

part 'apartment_local.g.dart';

/// Lokální Isar model reprezentující byt (apartment).
///
/// Offline-first: Data se primárně čtou z Isar, na pozadí se synchronizují
/// s Supabase. Pole [supabaseId] slouží ke spárování záznamu s cloudovým
/// záznamem při obousměrné synchronizaci.
///
/// [id] = Isar auto-increment pro lokální identifikaci
/// [supabaseId] = UUID z Supabase pro párování při sync
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

  /// Zda jsou lokální změny již odeslané do Supabase.
  @enumerated
  late SyncStatus syncStatus;

  /// Čas poslední změny v UTC. Používá se pro řazení a řešení konfliktů.
  late DateTime lastUpdated;
}
