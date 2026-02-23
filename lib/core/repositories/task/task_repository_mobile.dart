/// Implementace ITaskRepository pro mobilní/desktop platformy (iOS, Android, macOS, Windows).
///
/// Čte z lokální Isar databáze – offline-first. Tento soubor importuje Isar,
/// kompiluje se pouze pro dart:io (ne web).
import 'package:isar/isar.dart';

import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/database/models/apartment_local.dart';
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

    final filtered = taskLocals.where((t) => t.status != 'completed').toList();
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
    );
  }

  @override
  Future<void> updateTaskStatus(String tenantId, String taskId, String status) async {
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
      isar.taskLocals.putSync(task);
    });
  }
}

ITaskRepository getTaskRepository() => TaskRepositoryMobile();
