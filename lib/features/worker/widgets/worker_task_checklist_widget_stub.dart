import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web: žádný Drift/SQLite – prázdný placeholder (checklist je mobilní offline funkce).
///
/// PROČ: Import `database_provider`/`falconest_drift` by na webu vtáhl `sqlite3` → `dart:ffi` a build by spadl.
class WorkerTaskChecklistWidget extends ConsumerWidget {
  const WorkerTaskChecklistWidget({
    super.key,
    required this.taskId,
    this.readOnly = false,
  });

  final String taskId;
  /// Web nemá Drift – parametr slouží jen ke kompatibilnímu API s mobilní verzí.
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}
