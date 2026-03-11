/// Stub pro task_detail_provider – při nespecifikované platformě.
///
/// Volá se jen když ani dart.library.html ani dart.library.io nejsou dostupné.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/tasks/models/task_detail_data.dart';

final taskDetailProvider = FutureProvider.family<TaskDetailData?, int>((
  ref,
  taskId,
) async {
  throw UnsupportedError(
    'task_detail_provider není dostupný na této platformě',
  );
});

Future<void> updateTaskStatus(WidgetRef ref, {required int taskId, required String status}) {
  throw UnsupportedError(
    'updateTaskStatus není dostupný na této platformě',
  );
}

Future<void> saveTaskPhotoPath(WidgetRef ref, {required int taskId, required String photoPath}) {
  throw UnsupportedError(
    'saveTaskPhotoPath není dostupný na této platformě',
  );
}
