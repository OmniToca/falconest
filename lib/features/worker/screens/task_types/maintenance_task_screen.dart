import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';
import 'package:falconest/features/worker/widgets/worker_task_shared_header.dart';

/// Obsah scrollu pro údržbu – bez Scaffold.
abstract final class MaintenanceTaskScreen {
  MaintenanceTaskScreen._();

  static const Color backgroundColor = Color(0xFFFFF3E0);

  static List<Widget> buildAppBarActions(
    BuildContext context,
    WidgetRef ref,
    WorkerTaskDetail detail,
  ) {
    return [
      IconButton(
        icon: const Icon(Icons.report_problem_outlined),
        onPressed: () {
          final tenantId = ref.read(authNotifierProvider).tenantIdForData;
          if (tenantId == null || tenantId.isEmpty) return;
          showDialog(
            context: context,
            builder: (ctx) => IssueReporterDialog(
              tenantId: tenantId,
              apartmentId: detail.apartmentId,
            ),
          );
        },
      ),
    ];
  }

  static List<Widget> buildScrollChildren(WorkerTaskDetail detail) {
    return [
      WorkerTaskAddressContextBar(
        address: detail.displayAddress,
        latitude: detail.latitude,
        longitude: detail.longitude,
      ),
      const SizedBox(height: 16),
      ..._buildMaintenanceMetadata(detail),
    ];
  }

  static List<Widget> _buildMaintenanceMetadata(WorkerTaskDetail detail) {
    final note = detail.metadata?['custom_note'];
    final noteText = note is String
        ? note.trim()
        : (note?.toString().trim() ?? '');
    final descText = (detail.description).trim();
    final text = noteText.isNotEmpty ? noteText : descText;

    return [
      _buildProblemCard(
        text.isEmpty ? 'worker.maintenance_note_empty'.tr() : text,
      ),
    ];
  }

  static Widget _buildProblemCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.build, size: 24, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.custom_note'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
