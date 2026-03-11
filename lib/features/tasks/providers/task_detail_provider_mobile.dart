/// Mobilní implementace task_detail_provider – čte z Drift (SQLite).
///
/// Isar odstraněn. Načítá db.Task a db.Apartment z Drift a mapuje na TaskDetailData.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/features/tasks/models/task_detail_data.dart';

/// Načte detail úkolu podle Drift ID a mapuje na DTO.
final taskDetailProvider = FutureProvider.family<TaskDetailData?, int>((ref, taskId) async {
  try {
    final taskRepo = ref.watch(driftTaskRepositoryProvider);
    final task = await taskRepo.getTaskById(taskId);
    if (task == null) return null;

    String? apartmentName;
    String? apartmentAddress;
    String? apartmentKeybox;
    if (task.apartmentSupabaseId != null && task.apartmentSupabaseId!.trim().isNotEmpty) {
      final apartmentRepo = ref.watch(driftApartmentRepositoryProvider);
      final apt = await apartmentRepo.getBySupabaseId(task.apartmentSupabaseId!.trim());
      if (apt != null) {
        apartmentName = apt.name.trim().isEmpty ? null : apt.name.trim();
        apartmentAddress = (apt.address?.trim().isEmpty ?? true) ? null : apt.address?.trim();
        apartmentKeybox = (apt.keybox?.trim().isEmpty ?? true) ? null : apt.keybox?.trim();
      }
    }

    return TaskDetailData(
      taskId: taskId,
      scheduledStart: task.scheduledStart,
      status: task.status,
      photoUrl: (task.photoUrl?.trim().isEmpty ?? true) ? null : task.photoUrl?.trim(),
      apartmentName: apartmentName,
      apartmentAddress: apartmentAddress,
      apartmentKeybox: apartmentKeybox,
    );
  } catch (_) {
    return null;
  }
});

/// Aktualizuje stav úkolu v Drift – offline-first.
Future<void> updateTaskStatus(WidgetRef ref, {required int taskId, required String status}) async {
  final taskRepo = ref.read(driftTaskRepositoryProvider);
  final task = await taskRepo.getTaskById(taskId);
  if (task == null) return;
  final supabaseId = task.supabaseId;
  if (supabaseId == null || supabaseId.isEmpty) return;
  final tenantId = task.tenantId;
  await taskRepo.updateTaskStatus(tenantId, supabaseId, status);
}

/// Uloží cestu k lokální fotce do Drift.
Future<void> saveTaskPhotoPath(WidgetRef ref, {required int taskId, required String photoPath}) async {
  final taskRepo = ref.read(driftTaskRepositoryProvider);
  final task = await taskRepo.getTaskById(taskId);
  if (task == null) return;
  // DriftTaskRepository nemá saveTaskPhotoPath – úkol se aktualizuje přes updateTaskStatus
  // s metadata. Pro lokální foto se používá OFFLINE_TASK_COMPLETE_WITH_PHOTOS flow.
  // Task_detail_screen je deprecated – placeholder implementace.
}
