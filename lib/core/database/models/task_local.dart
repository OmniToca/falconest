import 'dart:convert';

import 'package:isar/isar.dart';

import 'sync_status.dart';

part 'task_local.g.dart';

/// Lokální Isar model reprezentující úkol (task).
///
/// Offline-first: Uživatel může vytvářet a měnit úkoly bez připojení.
/// [apartmentSupabaseId] odkazuje na byt – při sync se spáruje podle cloudového UUID.
/// [localUpdatedAt] se používá pro Timestamp Merging při řešení konfliktů.
/// [lastSyncedAt] – kdy byl záznam naposledy stažen z Supabase (null = nový lokální záznam).
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

  /// Supabase UUID rezervace – vazba na reservations. Pro automatický update statusu při Check-inu.
  String? reservationSupabaseId;

  /// Supabase UUID přiřazeného uživatele (profil). Null = nepřiřazeno.
  String? assignedUserSupabaseId;

  /// Název úkolu – mapuje tasks.title
  String title = '';

  /// Popis úkolu – mapuje tasks.description
  String description = '';

  /// Typ úkolu (cleaning, transfer_in, transfer_out, check_in, check_out, issue, material)
  /// – mapuje tasks.task_type
  String taskType = 'Jiné';

  /// Plánovaný začátek úkolu (časové pásmo UTC)
  late DateTime scheduledStart;

  /// Stav úkolu: pending, in_progress, completed, cancelled
  late String status;

  /// URL fotografie (např. z Supabase Storage)
  String? photoUrl;

  /// Čas poslední lokální úpravy v UTC. Klíčové pro Timestamp Merging – při
  /// konfliktu vyhrává novější časové razítko.
  late DateTime localUpdatedAt;

  /// Kdy byl záznam naposledy synchronizován z/do Supabase. Null = nový lokální záznam.
  DateTime? lastSyncedAt;

  /// Zda jsou lokální změny již odeslané do Supabase.
  @enumerated
  late SyncStatus syncStatus;

  /// Čas poslední změny – pro sync queue a řazení.
  late DateTime lastUpdated;

  /// Flexibilní metadata (JSONB z Supabase) – Isar nepodporuje Map, ukládáme jako JSON string.
  /// Při čtení: jsonDecode(metadataJson) pro Map. Při zápisu: jsonEncode(map).
  String? metadataJson;

  /// Reálný čas zahájení práce (UTC) – nastaví se při přechodu na in_progress.
  DateTime? startedAt;

  /// Reálný čas dokončení úkolu (UTC) – nastaví se při přechodu na completed.
  DateTime? completedAt;

  /// Implicitní konstruktor – potřebný pro Isar deserializaci a factory.
  TaskLocal();

  /// Vytvoří TaskLocal z mapy (např. JSON odpověď ze Supabase).
  ///
  /// Klíče: id, tenant_id, apartment_id, assigned_to, title, description,
  /// task_type, scheduled_start, status, photo_url, metadata, started_at, completed_at.
  /// metadata (JSONB) se serializuje do metadataJson.
  /// Pro vložení do Isar použij isar.taskLocals.put(obj) – id se přiřadí automaticky.
  factory TaskLocal.fromMap(Map<String, dynamic> map) {
    final rawStart = map['scheduled_start'] ?? map['due_date'];
    DateTime scheduledStart;
    if (rawStart is DateTime) {
      scheduledStart = rawStart.toUtc();
    } else if (rawStart is String) {
      scheduledStart = DateTime.tryParse(rawStart)?.toUtc() ?? DateTime.now().toUtc();
    } else {
      scheduledStart = DateTime.now().toUtc();
    }
    final now = DateTime.now().toUtc();
    final idRaw = map['id']?.toString().trim();
    return TaskLocal()
      ..supabaseId = (idRaw != null && idRaw.isNotEmpty) ? idRaw : null
      ..tenantId = (map['tenant_id']?.toString() ?? '').trim()
      ..apartmentSupabaseId = (map['apartment_id']?.toString() ?? '').trim().isEmpty
          ? null
          : (map['apartment_id']?.toString() ?? '').trim()
      ..reservationSupabaseId = (map['reservation_id']?.toString() ?? '').trim().isEmpty
          ? null
          : (map['reservation_id']?.toString() ?? '').trim()
      ..assignedUserSupabaseId = (map['assigned_to']?.toString() ?? '').trim().isEmpty
          ? null
          : (map['assigned_to']?.toString() ?? '').trim()
      ..title = (map['title']?.toString() ?? '').trim()
      ..description = (map['description']?.toString() ?? '').trim()
      ..taskType = (map['task_type']?.toString() ?? 'Jiné').trim()
      ..scheduledStart = scheduledStart
      ..status = (map['status']?.toString() ?? 'pending').trim()
      ..photoUrl = (map['photo_url']?.toString() ?? '').trim().isEmpty
          ? null
          : (map['photo_url']?.toString() ?? '').trim()
      ..localUpdatedAt = now
      ..lastSyncedAt = now
      ..syncStatus = SyncStatus.synced
      ..lastUpdated = now
      ..metadataJson = _encodeMetadata(map['metadata'])
      ..startedAt = _parseOptionalDateTime(map['started_at'])
      ..completedAt = _parseOptionalDateTime(map['completed_at']);
  }

  /// Parsuje volitelné časové razítko z Supabase (timestamptz).
  static DateTime? _parseOptionalDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    if (raw is String) return DateTime.tryParse(raw)?.toUtc();
    return null;
  }

  /// Serializuje metadata (Map/JSONB) do JSON stringu pro Isar.
  static String? _encodeMetadata(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      if (m.isEmpty) return null;
      return jsonEncode(m);
    }
    return null;
  }
}
