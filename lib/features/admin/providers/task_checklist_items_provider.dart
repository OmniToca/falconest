import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/repositories/task_checklist_instance_repository.dart';

/// Načte **instanci** checklistu u úkolu: jeden řádek `task_checklists` a seřazené `task_checklist_items`.
///
/// PROČ: Pro editaci v admin dialogu potřebujeme jak [TaskChecklistInstanceData.taskChecklistId],
/// tak seznam položek; název provideru odpovídá zadání (fokus na položky v `task_checklist_items`).
final taskChecklistItemsProvider =
    FutureProvider.autoDispose.family<TaskChecklistInstanceData?, String>((ref, taskId) async {
  final tenantId = ref.watch(authNotifierProvider.select((s) => s.tenantIdForData));
  if (tenantId == null || tenantId.isEmpty || taskId.isEmpty) return null;
  return TaskChecklistInstanceRepository.instance.fetchForTask(tenantId, taskId);
});
