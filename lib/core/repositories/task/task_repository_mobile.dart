/// Implementace ITaskRepository pro mobilní/desktop platformy (iOS, Android, macOS, Windows).
///
/// Čte z lokální Isar databáze – offline-first. Tento soubor importuje Isar,
/// kompiluje se pouze pro dart:io (ne web).
import 'dart:convert';

import 'package:isar/isar.dart';

import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/database/models/apartment_local.dart';
import 'package:falconest/core/database/models/reservation_local.dart';
import 'package:falconest/core/database/models/sync_status.dart';
import 'package:falconest/core/database/models/task_local.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';

class TaskRepositoryMobile implements ITaskRepository {
  @override
  Future<List<WorkerTask>> getWorkerTasks(String tenantId, String workerId) async {
    final isar = IsarService.instance;
    final taskLocals = isar.taskLocals
        .filter()
        .tenantIdEqualTo(tenantId)
        .assignedUserSupabaseIdEqualTo(workerId)
        .findAllSync();

    // Dashboard zobrazuje jen assigned a in_progress – vyloučení pending (návrhů) i completed.
    final filtered = taskLocals.where((t) {
      final s = t.status.trim().toLowerCase();
      if (s == 'completed' || s == 'done' || s == 'dokončeno' || s == 'hotovo') return false;
      if (s == 'pending' || s == 'draft' || s == 'nový' || s == 'new') return false;
      return true;
    }).toList();
    filtered.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

    return _mapToWorkerTasks(isar, filtered);
  }

  List<WorkerTask> _mapToWorkerTasks(Isar isar, List<TaskLocal> taskLocals) {
    final result = <WorkerTask>[];
    for (final t in taskLocals) {
      final idStr = t.supabaseId ?? '';
      if (idStr.isEmpty) continue;

      String? aptName;
      String? aptAddress;
      if (t.apartmentSupabaseId != null && t.apartmentSupabaseId!.isNotEmpty) {
        final apt = isar.apartmentLocals
            .filter()
            .supabaseIdEqualTo(t.apartmentSupabaseId)
            .findFirstSync();
        if (apt != null) {
          aptName = apt.name.trim().isEmpty ? null : apt.name.trim();
          aptAddress = (apt.address?.trim().isEmpty ?? true) ? null : apt.address?.trim();
        }
      }

      result.add(WorkerTask(
        id: idStr,
        title: t.title.trim(),
        description: t.description.trim(),
        taskType: t.taskType.trim(),
        scheduledStart: t.scheduledStart.toLocal(),
        status: t.status.trim(),
        apartmentId: t.apartmentSupabaseId?.trim() ?? '',
        apartmentName: aptName,
        apartmentAddress: aptAddress,
      ));
    }
    return result;
  }

  @override
  Future<WorkerTaskDetail?> getWorkerTaskDetail(String tenantId, String taskId) async {
    final isar = IsarService.instance;
    final task = isar.taskLocals
        .filter()
        .tenantIdEqualTo(tenantId)
        .supabaseIdEqualTo(taskId)
        .findFirstSync();
    if (task == null) return null;
    ApartmentLocal? apt;
    if (task.apartmentSupabaseId != null && task.apartmentSupabaseId!.isNotEmpty) {
      apt = isar.apartmentLocals
          .filter()
          .supabaseIdEqualTo(task.apartmentSupabaseId)
          .findFirstSync();
    }
    return WorkerTaskDetail(
      id: task.supabaseId ?? taskId,
      title: task.title.trim(),
      description: task.description.trim(),
      taskType: task.taskType.trim(),
      scheduledStart: task.scheduledStart.toLocal(),
      status: task.status.trim(),
      apartmentId: task.apartmentSupabaseId?.trim() ?? '',
      apartmentName: apt != null && apt.name.trim().isNotEmpty ? apt.name.trim() : null,
      apartmentAddress: apt != null && (apt.address?.trim().isEmpty ?? true) == false ? apt.address!.trim() : null,
      keybox: apt != null && (apt.keybox?.trim().isEmpty ?? true) == false ? apt.keybox!.trim() : null,
      ownerNotes: apt != null && (apt.ownerNotes?.trim().isEmpty ?? true) == false ? apt.ownerNotes!.trim() : null,
      photoUrl: (task.photoUrl?.trim().isEmpty ?? true) ? null : task.photoUrl,
      metadata: _parseMetadata(task.metadataJson),
      startedAt: task.startedAt,
      completedAt: task.completedAt,
    );
  }

  /// Rozparsuje metadataJson string na Map (null-safe).
  static Map<String, dynamic>? _parseMetadata(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  @override
  Future<void> updateTaskStatus(
    String tenantId,
    String taskId,
    String status, {
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadataOverlay,
  }) async {
    final isar = IsarService.instance;
    final task = isar.taskLocals
        .filter()
        .tenantIdEqualTo(tenantId)
        .supabaseIdEqualTo(taskId)
        .findFirstSync();
    if (task == null) return;
    isar.writeTxnSync(() {
      task.status = status.trim();
      task.localUpdatedAt = DateTime.now().toUtc();
      task.lastUpdated = DateTime.now().toUtc();
      task.syncStatus = SyncStatus.pending;
      // Uložení přesného UTC času pro sledování reálné doby práce.
      if (startedAt != null) task.startedAt = startedAt.toUtc();
      if (completedAt != null) task.completedAt = completedAt.toUtc();
      if (metadataOverlay != null && metadataOverlay.isNotEmpty) {
        final existing = _parseMetadata(task.metadataJson) ?? {};
        final merged = Map<String, dynamic>.from(existing)..addAll(metadataOverlay);
        task.metadataJson = jsonEncode(merged);
      }
      isar.taskLocals.putSync(task);

      // Byznysové pravidlo: Jakmile pracovník fyzicky dokončí Check-in úkol, automaticky posouváme
      // celou rezervaci do stavu checked_in. Řešeno offline-first.
      final isCheckInComplete =
          status.trim().toLowerCase() == 'completed' &&
          (task.taskType.contains('check_in') || task.taskType.contains('check-in'));
      if (isCheckInComplete &&
          task.reservationSupabaseId != null &&
          task.reservationSupabaseId!.trim().isNotEmpty) {
        final res = isar.reservationLocals
            .filter()
            .tenantIdEqualTo(tenantId)
            .supabaseIdEqualTo(task.reservationSupabaseId!)
            .findFirstSync();
        if (res != null) {
          res.status = 'checked_in';
          res.localUpdatedAt = DateTime.now().toUtc();
          res.lastUpdated = DateTime.now().toUtc();
          res.syncStatus = SyncStatus.pending;
          isar.reservationLocals.putSync(res);
        }
      }

      // Byznysové pravidlo: Dokončením úkolu Check-out automaticky měníme stav celé rezervace
      // na checked_out. Synchronizováno offline-first.
      final isCheckOutComplete =
          status.trim().toLowerCase() == 'completed' &&
          (task.taskType.contains('check_out') || task.taskType.contains('checkout'));
      if (isCheckOutComplete &&
          task.reservationSupabaseId != null &&
          task.reservationSupabaseId!.trim().isNotEmpty) {
        final res = isar.reservationLocals
            .filter()
            .tenantIdEqualTo(tenantId)
            .supabaseIdEqualTo(task.reservationSupabaseId!)
            .findFirstSync();
        if (res != null) {
          res.status = 'checked_out';
          res.localUpdatedAt = DateTime.now().toUtc();
          res.lastUpdated = DateTime.now().toUtc();
          res.syncStatus = SyncStatus.pending;
          isar.reservationLocals.putSync(res);
        }
      }
    });
  }
}

ITaskRepository getTaskRepository() => TaskRepositoryMobile();
