/// Abstraktní rozhraní pro repozitář úkolů – Clean Architecture.
///
/// Odděluje datovou vrstvu od UI. Na webu implementace čte ze Supabase,
/// na mobilu z lokální Isar databáze (offline-first).
/// Doménový model WorkerTask nemá žádnou závislost na Isar.

/// Model úkolu pro Worker – platformově nezávislý DTO.
class WorkerTask {
  const WorkerTask({
    required this.id,
    required this.title,
    required this.description,
    required this.taskType,
    required this.scheduledStart,
    required this.status,
    required this.apartmentId,
    this.apartmentName,
    this.apartmentAddress,
  });

  final String id;
  final String title;
  final String description;
  final String taskType;
  final DateTime scheduledStart;
  final String status;
  final String apartmentId;
  final String? apartmentName;
  final String? apartmentAddress;
}

/// Detail úkolu pro Worker Task Detail Screen (keybox, ownerNotes, photoUrl, metadata, časová razítka).
class WorkerTaskDetail {
  const WorkerTaskDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.taskType,
    required this.scheduledStart,
    required this.status,
    required this.apartmentId,
    this.apartmentName,
    this.apartmentAddress,
    this.keybox,
    this.ownerNotes,
    this.photoUrl,
    this.metadata,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String description;
  final String taskType;
  final DateTime scheduledStart;
  final String status;
  final String apartmentId;
  final String? apartmentName;
  final String? apartmentAddress;
  final String? keybox;
  final String? ownerNotes;
  final String? photoUrl;
  /// JSONB metadata z tasks (amount_to_collect, custom_note, expected_audit_total, collection_breakdown).
  final Map<String, dynamic>? metadata;
  /// Reálný čas zahájení práce (UTC).
  final DateTime? startedAt;
  /// Reálný čas dokončení úkolu (UTC).
  final DateTime? completedAt;
}

/// Repozitář pro čtení úkolů přiřazených pracovníkovi.
///
/// Implementace se vybírá podmíněným importem (web vs. mobil).
abstract class ITaskRepository {
  /// Načte úkoly přiřazené pracovníkovi. Vynechá completed.
  Future<List<WorkerTask>> getWorkerTasks(String tenantId, String workerId);

  /// Načte detail úkolu podle Supabase UUID.
  Future<WorkerTaskDetail?> getWorkerTaskDetail(String tenantId, String taskId);

  /// Aktualizuje status úkolu (offline: pending, pak sync).
  /// [startedAt] – nastaví se při přechodu do in_progress (Time Tracking).
  /// [completedAt] – nastaví se při přechodu do completed (Time Tracking).
  /// [metadataOverlay] – volitelně sloučí dodatečné klíče do metadata (např. cash_collection_failed).
  Future<void> updateTaskStatus(
    String tenantId,
    String taskId,
    String status, {
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadataOverlay,
  });
}
