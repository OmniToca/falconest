import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest/core/repositories/task/task_repository_web.dart';

/// Webový provider pro TaskRepository – vrací Supabase implementaci.
final taskRepositoryProvider = Provider<ITaskRepository>((ref) {
  return TaskRepositoryWeb();
});
