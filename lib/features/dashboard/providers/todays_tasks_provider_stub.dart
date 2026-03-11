/// Stub pro todays_tasks_provider – při nespecifikované platformě.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/repositories/task/task_repository.dart';

final todaysTasksProvider = Provider<List<WorkerTask>>((ref) {
  throw UnsupportedError(
    'todays_tasks_provider není dostupný na této platformě',
  );
});
