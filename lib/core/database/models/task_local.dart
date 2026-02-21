import 'package:isar/isar.dart';

import 'sync_status.dart';

part 'task_local.g.dart';

/// Lokální Isar model reprezentující úkol (task).
///
/// Offline-first: Uživatel může vytvářet a měnit úkoly bez připojení.
/// [apartmentSupabaseId] odkazuje na byt – při sync se spáruje podle cloudového UUID.
/// [localUpdatedAt] se používá pro Timestamp Merging při řešení konfliktů.
///
@collection
class TaskLocal {
  /// Automaticky generované Isar ID pro lokální jednoznačnost.
  Id id = Isar.autoIncrement;

  /// UUID záznamu v Supabase. Null = nový úkol ještě neodeslaný.
  String? supabaseId;

  /// ID tenanta – multi-tenant izolace
  late String tenantId;

  /// Supabase UUID bytu, ke kterému úkol patří.
  /// Pro lokální zobrazení lze vyhledat ApartmentLocal podle supabaseId.
  String? apartmentSupabaseId;

  /// Supabase UUID přiřazeného uživatele (profil). Null = nepřiřazeno.
  String? assignedUserSupabaseId;

  /// Plánovaný začátek úkolu (časové pásmo UTC)
  late DateTime scheduledStart;

  /// Stav úkolu: pending, in_progress, completed, cancelled
  late String status;

  /// URL fotografie (např. z Supabase Storage)
  String? photoUrl;

  /// Čas poslední lokální úpravy v UTC. Klíčové pro Timestamp Merging – při
  /// konfliktu vyhrává novější časové razítko.
  late DateTime localUpdatedAt;

  /// Zda jsou lokální změny již odeslané do Supabase.
  @enumerated
  late SyncStatus syncStatus;

  /// Čas poslední změny – pro sync queue a řazení.
  late DateTime lastUpdated;
}
