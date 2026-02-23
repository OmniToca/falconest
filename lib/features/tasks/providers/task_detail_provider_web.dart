/// Webová implementace task_detail_provider.
///
/// Web nepoužívá Isar – route /task/:id je legacy a očekává Isar ID.
/// Na webu vždy vracíme null (úkol nenalezen). updateTaskStatus a saveTaskPhotoPath
/// jsou no-op (web nemá lokální úkoly).
///
/// STRICT: Tento soubor nesmí importovat isar ani .g.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/tasks/models/task_detail_data.dart';

/// Na webu Isar není – vždy null.
final taskDetailProvider = FutureProvider.family<TaskDetailData?, int>((
  ref,
  taskId,
) async => null);

/// No-op na webu.
Future<void> updateTaskStatus({
  required int taskId,
  required String status,
}) async {}

/// No-op na webu.
Future<void> saveTaskPhotoPath({
  required int taskId,
  required String photoPath,
}) async {}
