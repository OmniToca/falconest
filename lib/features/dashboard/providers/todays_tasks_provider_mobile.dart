/// Mobilní implementace todays_tasks_provider – čte z Isar.
///
/// Filtruje úkoly podle dnešního data (scheduledStart) a mapuje na [WorkerTask].
/// Používá se na legacy route /task/:id pro invalidaci po změně stavu.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import 'package:falconest/core/database/isar_service.dart';
import 'package:falconest/core/database/models/apartment_local.dart';
import 'package:falconest/core/database/models/task_local.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';

/// Načte dnešní úkoly z Isar – filtruje podle [scheduledStart] v aktuálním dni.
final todaysTasksProvider = Provider<List<WorkerTask>>((ref) {
  try {
    final isar = IsarService.instance;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    final results = isar.taskLocals
        .where()
        .anyId()
        .filter()
        .scheduledStartBetween(startOfToday, endOfToday, includeUpper: false)
        .findAllSync();
    results.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

    return _mapToWorkerTasks(isar, results);
  } catch (_) {
    return [];
  }
});

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
