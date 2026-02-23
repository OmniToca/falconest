import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/screens/task_types/checkin_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/checkout_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/cleaning_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/default_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/issue_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/maintenance_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/material_task_screen.dart';
import 'package:falconest/features/worker/screens/task_types/transfer_task_screen.dart';

/// Rozcestník detailu úkolu – načte data a podle task_type zobrazí MVP obrazovku daného typu.
/// Neviditelný wrapper: providers a routování beze změny, mění se pouze vykreslovaný widget.
class WorkerTaskDetailScreen extends ConsumerWidget {
  const WorkerTaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(workerTaskDetailProvider(taskId));

    return detailAsync.when(
      data: (detail) {
        if (detail == null) {
          return _buildNotFound(context);
        }
        final type = detail.taskType.trim().toLowerCase();
        if (type == 'transfer_in' || type == 'transfer_out') {
          return TransferTaskScreen(taskId: taskId);
        }
        if (type == 'check_in') {
          return CheckinTaskScreen(taskId: taskId);
        }
        if (type == 'check_out') {
          return CheckoutTaskScreen(taskId: taskId);
        }
        if (type == 'issue') {
          return IssueTaskScreen(taskId: taskId);
        }
        if (type == 'cleaning') {
          return CleaningTaskScreen(taskId: taskId);
        }
        if (type == 'maintenance') {
          return MaintenanceTaskScreen(taskId: taskId);
        }
        if (type == 'material') {
          return MaterialTaskScreen(taskId: taskId);
        }
        return DefaultTaskScreen(taskId: taskId);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _buildNotFound(context),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'worker.task_detail_not_found'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/worker'),
                icon: const Icon(Icons.arrow_back),
                label: Text('common.back'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
