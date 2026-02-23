/// Mobilní implementace task_detail_provider – čte z Isar.
///
/// Načítá TaskLocal a ApartmentLocal z lokální databáze a mapuje na
/// [TaskDetailData] DTO pro jednotné rozhraní s webem.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/database/models/apartment_local.dart';
import 'package:falconest/core/database/models/sync_status.dart';
import 'package:falconest/core/database/models/task_local.dart';
import 'package:falconest/features/tasks/models/task_detail_data.dart';

/// Načte detail úkolu podle Isar ID a mapuje na DTO.
final taskDetailProvider = FutureProvider.family<TaskDetailData?, int>((
  ref,
  taskId,
) async {
  try {
    final isar = IsarService.instance;

    final task = isar.taskLocals.getSync(taskId);
    if (task == null) return null;

    ApartmentLocal? apartment;
    if (task.apartmentSupabaseId != null) {
      apartment = isar.apartmentLocals
          .where()
          .anyId()
          .filter()
          .supabaseIdEqualTo(task.apartmentSupabaseId)
          .findFirstSync();
    }

    return TaskDetailData(
      taskId: taskId,
      scheduledStart: task.scheduledStart,
      status: task.status,
      photoUrl: (task.photoUrl?.trim().isEmpty ?? true) ? null : task.photoUrl?.trim(),
      apartmentName: apartment != null && apartment.name.trim().isNotEmpty
          ? apartment.name.trim()
          : null,
      apartmentAddress: apartment != null &&
              (apartment.address?.trim().isEmpty ?? true) == false
          ? apartment.address!.trim()
          : null,
      apartmentKeybox: apartment != null &&
              (apartment.keybox?.trim().isEmpty ?? true) == false
          ? apartment.keybox!.trim()
          : null,
    );
  } catch (_) {
    return null;
  }
});

/// Aktualizuje stav úkolu v Isar – offline-first.
Future<void> updateTaskStatus({
  required int taskId,
  required String status,
}) async {
  final isar = IsarService.instance;
  final task = isar.taskLocals.getSync(taskId);
  if (task == null) return;

  task.status = status;
  task.syncStatus = SyncStatus.pending;
  task.lastUpdated = DateTime.now().toUtc();
  task.localUpdatedAt = DateTime.now().toUtc();

  await isar.writeTxn(() async {
    await isar.taskLocals.put(task);
  });
}

/// Uloží cestu k lokální fotce do Isar.
Future<void> saveTaskPhotoPath({
  required int taskId,
  required String photoPath,
}) async {
  final isar = IsarService.instance;
  final task = isar.taskLocals.getSync(taskId);
  if (task == null) return;

  task.photoUrl = photoPath;
  task.syncStatus = SyncStatus.pending;
  task.lastUpdated = DateTime.now().toUtc();
  task.localUpdatedAt = DateTime.now().toUtc();

  await isar.writeTxn(() async {
    await isar.taskLocals.put(task);
  });
}
