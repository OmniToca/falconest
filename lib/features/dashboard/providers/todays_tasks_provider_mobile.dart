/// Mobilní implementace todays_tasks_provider – legacy route /task/:id.
///
/// Isar odstraněn. Task_detail_screen je deprecated – vracíme prázdný seznam.
/// Worker dashboard používá workerTasksProvider.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/repositories/task/task_repository.dart';

final todaysTasksProvider = Provider<List<WorkerTask>>((ref) => []);
