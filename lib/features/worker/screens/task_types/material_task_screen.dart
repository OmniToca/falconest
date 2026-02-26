import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/widgets/task_header_widget.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';

const _primaryBlue = Color(0xFF1565C0);

/// Specifická obrazovka pro úkoly typu Materiál (doplňování materiálu).
///
/// Zobrazuje adresu s navigací, čas, seznam materiálu k doplnění (z custom_note
/// nebo description) a tlačítka Zahájit práci / Materiál doplněn.
/// Používá standardní offline-first provider pro aktualizaci stavu (Isar + sync),
/// ale poskytuje uživateli přesnější texty (Materiál doplněn).
class MaterialTaskScreen extends ConsumerWidget {
  const MaterialTaskScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(workerTaskDetailProvider(taskId));

    return detailAsync.when(
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            body: Center(child: Text('worker.task_detail_not_found'.tr())),
          );
        }
        return Scaffold(
          backgroundColor: const Color(0xFFE8F5E9),
          appBar: AppBar(
            title: Text(
              detail.title.isNotEmpty ? detail.title : detail.apartmentName ?? '—',
              style: const TextStyle(color: Colors.black87),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black87,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black87),
            actions: [
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
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TaskHeaderWidget(
                          title: detail.title.isNotEmpty ? detail.title : detail.apartmentName ?? '—',
                          scheduledStart: detail.scheduledStart,
                        ),
                        const SizedBox(height: 16),
                        _buildAddressWithNavigate(context, detail.apartmentAddress),
                        const SizedBox(height: 16),
                        ..._buildMaterialMetadata(context, detail),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  context,
                  ref,
                  taskId,
                  detail.status,
                  'worker.action_material_restocked',
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(
        body: Center(child: Text('worker.task_detail_not_found'.tr())),
      ),
    );
  }

  Widget _buildAddressWithNavigate(BuildContext context, String? address) {
    final addr = address?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          addr.isEmpty ? '—' : addr,
          style: TextStyle(fontSize: 17, color: Colors.grey.shade800),
        ),
        if (addr.isNotEmpty) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _openMaps(context, addr),
            icon: const Icon(Icons.map, size: 20),
            label: Text('worker.task_detail_navigate'.tr()),
          ),
        ],
      ],
    );
  }

  Future<void> _openMaps(BuildContext context, String address) async {
    final query = address.trim();
    if (query.isEmpty) return;
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Seznam materiálu k doplnění z custom_note nebo description.
  /// Prázdný fallback má i18n text.
  List<Widget> _buildMaterialMetadata(BuildContext context, dynamic detail) {
    final note = detail.metadata?['custom_note'];
    final noteText =
        note is String ? note.trim() : (note?.toString().trim() ?? '');
    final descText = (detail.description ?? '').trim();
    final text = noteText.isNotEmpty ? noteText : descText;

    return [
      _buildMaterialCard(
        text.isEmpty ? 'worker.material_list_empty'.tr() : text,
      ),
    ];
  }

  Widget _buildMaterialCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.inventory_2_outlined, size: 24, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.material_to_restock'.tr(),
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

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    String taskId,
    String status,
    String finishKey,
  ) {
    final s = status.trim().toLowerCase();
    final isInProgress = s == 'in_progress' || s == 'probíhá';
    final isCompleted =
        s == 'completed' || s == 'done' || s == 'dokončeno' || s == 'hotovo';

    if (isCompleted) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => context.pop(),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text('common.back'.tr()),
        ),
      );
    }
    if (isInProgress) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('worker.confirm_finish_title'.tr()),
                content: Text('worker.confirm_finish_message'.tr()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('common.cancel'.tr()),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('common.ok'.tr()),
                  ),
                ],
              ),
            );
            if (ok != true || !context.mounted) return;
            await ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(
                  taskId,
                  'completed',
                  completedAt: DateTime.now().toUtc(),
                );
            if (context.mounted) context.pop();
          },
          style: FilledButton.styleFrom(
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(finishKey.tr()),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('worker.confirm_start_title'.tr()),
              content: Text('worker.confirm_start_message'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('common.cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text('common.ok'.tr()),
                ),
              ],
            ),
          );
          if (ok != true) return;
          await ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(
                taskId,
                'in_progress',
                startedAt: DateTime.now().toUtc(),
              );
        },
        style: FilledButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text('worker.task_detail_start_work'.tr()),
      ),
    );
  }
}
