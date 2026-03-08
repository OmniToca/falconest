import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest/core/repositories/task/task_repository_provider_export.dart';

/// Re-export doménového modelu pro konzumenty (Worker UI).
export 'package:falconest/core/repositories/task/task_repository.dart' show WorkerTask;

/// Načte úkoly přiřazené aktuálnímu uživateli.
///
/// Používá taskRepositoryProvider – na webu Supabase, na mobilu Drift (SQLite).
/// Drift zajišťuje 100 % offline stabilitu na iOS bez výpadků.
final workerTasksProvider = FutureProvider<List<WorkerTask>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final tenantId = auth.tenantIdForData;
  final workerId = auth.state.profileId;
  if (tenantId == null ||
      tenantId.isEmpty ||
      workerId == null ||
      workerId.isEmpty) {
    return [];
  }

  try {
    final repo = ref.watch(taskRepositoryProvider);
    return repo.getWorkerTasks(tenantId, workerId);
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('WorkerDashboard: TASK REPO ERROR: $e');
    }
    return [];
  }
});
