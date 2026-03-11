/// Webová implementace todays_tasks_provider.
///
/// Web nepoužívá Isar – na /worker se používá worker_dashboard_provider
/// (Supabase). Tento provider vrací prázdný seznam. Používá se jen pro
/// invalidaci z TaskDetailScreen (legacy route /task/:id).
///
/// STRICT: Tento soubor nesmí importovat isar ani .g.dart.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/repositories/task/task_repository.dart';

/// Na webu vždy prázdný seznam.
final todaysTasksProvider = Provider<List<WorkerTask>>((ref) => []);
