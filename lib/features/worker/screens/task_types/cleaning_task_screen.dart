import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/widgets/sync_status_icon.dart';
import 'package:falconest/core/widgets/task_header_widget.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/utils/cash_collection_dialog.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';

const _primaryBlue = Color(0xFF1565C0);

/// MVP obrazovka pro úkoly typu Úklid.
/// Jednoduché zobrazení dat a tlačítko Dokončit.
class CleaningTaskScreen extends ConsumerWidget {
  const CleaningTaskScreen({super.key, required this.taskId});

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
          backgroundColor: const Color(0xFFF3E5F5),
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
              const SyncStatusIcon(),
              IconButton(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                tooltip: 'worker.cash_enter_button_tooltip'.tr(),
                onPressed: () async {
                  await maybeShowCashCollectionDialog(
                    context,
                    ref,
                    detail,
                    taskId: taskId,
                    onCompleted: () {},
                    forceShowForExtraOnly: true,
                    completeTaskOnConfirm: false,
                  );
                },
              ),
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
                        // Sjednocená hlavička podle vzoru Check-in (nadpis + datum/čas s ikonou hodin).
                        TaskHeaderWidget(
                          title: detail.title.isNotEmpty ? detail.title : detail.apartmentName ?? '—',
                          scheduledStart: detail.scheduledStart,
                        ),
                        const SizedBox(height: 16),
                        // PROČ: Odpočet času při aktivním úkolu – uklízečka vidí zbývající čas či zpoždění.
                        TaskCountdownTimer(
                          startedAt: detail.startedAt,
                          completedAt: detail.completedAt,
                          estimatedMinutes: parseTaskEstimateMinutes(
                            detail.description,
                            detail.metadata,
                          ),
                        ),
                        // PROČ: Tlačítko Navigovat – uklízečka potřebuje cestu k bytu, stejně jako ostatní profese.
                        _buildAddressWithNavigate(context, detail.apartmentAddress),
                        const SizedBox(height: 16),
                        // PROČ: Kód schránky a poznámky majitele – kritické pro vstup do bytu (bez kontaktu na hosta).
                        ..._buildKeyboxAndOwnerNotes(detail),
                        const SizedBox(height: 12),
                        // PROČ: Odhad času z description (např. "Odhad: 180 min") – uklízečka potřebuje plánovat čas.
                        ..._buildTimeEstimateCard(detail.description),
                        // PROČ: custom_note a instructions z metadat – důležité instrukce v odlišené kartě (žlutá = důraz).
                        ..._buildCleaningMetadata(detail.metadata ?? {}),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionButton(context, ref, taskId, detail.status, 'worker.task_detail_finish'),
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

  Widget _buildActionButton(BuildContext context, WidgetRef ref, String taskId, String status, String finishKey) {
    final s = status.trim().toLowerCase();
    final isInProgress = s == 'in_progress' || s == 'probíhá';
    final isCompleted = s == 'completed' || s == 'done' || s == 'dokončeno' || s == 'hotovo';

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

    // Dvoufázové odpracování: Nejprve Zahájit (in_progress), poté Dokončit (completed).
    // Uložení přesného UTC času pro sledování reálné doby práce.
    // PROČ: Potvrzovací dialog zabrání překlikům v kapse při dokončení.
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

    // PROČ: Potvrzovací dialog zabrání překlikům v kapse při zahájení.
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

  /// Adresa s tlačítkem Navigovat – otevře Google Maps.
  Widget _buildAddressWithNavigate(BuildContext context, String? address) {
    final addr = address?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          addr.isEmpty ? '—' : addr,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
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
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Kód schránky a poznámky majitele – uklízečka potřebuje klíče a instrukce.
  List<Widget> _buildKeyboxAndOwnerNotes(WorkerTaskDetail detail) {
    final widgets = <Widget>[];
    final keybox = detail.keybox?.trim();
    final notes = detail.ownerNotes?.trim();
    if (keybox != null && keybox.isNotEmpty) {
      widgets.add(_buildInfoCard('worker.label_keybox'.tr(), keybox, Icons.key));
      widgets.add(const SizedBox(height: 12));
    }
    if (notes != null && notes.isNotEmpty) {
      widgets.add(_buildInfoCard('worker.label_owner_notes'.tr(), notes, Icons.note_outlined));
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.purple.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Parsuje odhad času z description (např. "Odhad: 180 min" dle AUDIT_TASK_GENERATOR).
  /// Regex zachytí i vícejazyčné varianty "X min" pro flexibilitu.
  List<Widget> _buildTimeEstimateCard(String description) {
    if (description.trim().isEmpty) return [];
    final match = RegExp(r'(?:Odhad|Estimate|Estimación)[:\s]*(\d+)\s*min|(\d+)\s*min')
        .firstMatch(description.trim());
    final minutes = match != null ? (int.tryParse(match.group(1) ?? '') ?? int.tryParse(match.group(2) ?? '')) : null;
    if (minutes == null || minutes <= 0) return [];

    return [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.access_time, size: 24, color: Colors.purple.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'worker.cleaning_time_estimate'.tr(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'worker.cleaning_time_estimate_minutes'.tr(namedArgs: {'minutes': '$minutes'}),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Vykreslení metadat pro Úklid – custom_note a instructions. Bezpečnost: žádné finance.
  /// Žluté pozadí = vizuální důraz na důležité instrukce. Pokud prázdné, karta se nezobrazí.
  List<Widget> _buildCleaningMetadata(Map<String, dynamic> meta) {
    final note = meta['custom_note'];
    final instructions = meta['instructions'];
    final noteText = note is String ? note.trim() : (note?.toString().trim() ?? '');
    final instructionsText = instructions is String ? instructions.trim() : (instructions?.toString().trim() ?? '');
    final combined = [noteText, instructionsText].where((s) => s.isNotEmpty).join('\n\n');
    if (combined.isEmpty) return [];

    return [
      const SizedBox(height: 12),
      _buildCustomInstructionsCard(combined),
    ];
  }

  /// Karta vlastních instrukcí – světle žluté pozadí pro vizuální důraz, ikona info.
  Widget _buildCustomInstructionsCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outlined, size: 24, color: Colors.amber.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.cleaning_custom_instructions'.tr(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(text, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
