import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/repositories/task/task_repository.dart';

/// Fallback provider – vyhodí při přístupu. Pro platformy bez task repozitáře.
final taskRepositoryProvider = Provider<ITaskRepository>((ref) {
  throw UnsupportedError('TaskRepositoryProvider není dostupný na této platformě.');
});
