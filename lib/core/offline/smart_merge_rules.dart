/// Čistá pravidla Timestamp Merging / Smart Merge pro offline sync (worker → Supabase).
///
/// PROČ odděleně od [WorkerSyncService]: byznysová pravidla musí jít unit-testovat bez
/// Driftu a sítě. Sync služba je jen orchestrátor (fetch → merge → push → local apply).
library;

/// Detekce konfliktu: server má novější [updated_at] než lokální [lastSyncedAt].
///
/// PROČ: Bez toho by platilo last-write-wins a worker by po syncu přepsal admin změny.
bool hasTimestampMergeConflict({
  required DateTime? serverUpdatedAt,
  required DateTime? lastSyncedAt,
}) {
  if (serverUpdatedAt == null) return false;
  if (lastSyncedAt == null) return true;
  return serverUpdatedAt.toUtc().isAfter(lastSyncedAt.toUtc());
}

/// Sloučí poznámky při konfliktu: zachová admin i worker text.
///
/// PROČ: Ani terénní, ani dispečerská informace se nesmí ztratit při souběžné editaci.
String mergeConflictNotes({String? serverNotes, String? localNotes}) {
  final server = (serverNotes ?? '').trim();
  final local = (localNotes ?? '').trim();
  if (server.isEmpty) return local;
  if (local.isEmpty) return server;
  if (server == local) return local;
  return '[Admin]: $server\n[Worker]: $local';
}

/// Sloučí metadata: základ ze serveru, lokální klíče přepíší duplicity.
///
/// PROČ: Worker typicky doplňuje provozní klíče (foto, hotovost); admin drží ceník/termíny.
Map<String, dynamic> mergeMetadataMaps(
  Map<String, dynamic> server, [
  Map<String, dynamic>? local,
]) {
  final out = Map<String, dynamic>.from(server);
  if (local != null && local.isNotEmpty) {
    for (final e in local.entries) {
      out[e.key] = e.value;
    }
  }
  return out;
}

/// Výsledek Smart Merge pro úkol – status vždy z workera, admin pole ze serveru.
///
/// PROČ PRAVIDLO 1: Worker byl na místě; jeho status (completed / in_progress) má přednost.
class TaskSmartMergeResult {
  const TaskSmartMergeResult({
    required this.status,
    required this.description,
    required this.metadata,
    this.title,
    this.taskType,
    this.scheduledStart,
  });

  final String status;
  final String description;
  final Map<String, dynamic> metadata;
  final String? title;
  final String? taskType;
  final DateTime? scheduledStart;
}

/// Aplikuje byznysová pravidla Smart Merge na konfliktní úkol.
TaskSmartMergeResult applyTaskSmartMerge({
  required String localStatus,
  required String localDescription,
  required Map<String, dynamic>? localMetadata,
  required String? serverDescription,
  required Map<String, dynamic>? serverMetadata,
  required String? serverTitle,
  required String? serverTaskType,
  required DateTime? serverScheduledStart,
}) {
  return TaskSmartMergeResult(
    status: localStatus,
    description: mergeConflictNotes(
      serverNotes: serverDescription,
      localNotes: localDescription,
    ),
    metadata: mergeMetadataMaps(
      serverMetadata ?? const <String, dynamic>{},
      localMetadata,
    ),
    title: serverTitle?.trim().isEmpty == true ? null : serverTitle?.trim(),
    taskType:
        serverTaskType?.trim().isEmpty == true ? null : serverTaskType?.trim(),
    scheduledStart: serverScheduledStart?.toUtc(),
  );
}
