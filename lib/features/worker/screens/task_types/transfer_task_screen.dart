import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/widgets/task_header_widget.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';
import 'package:falconest/features/worker/utils/cash_collection_dialog.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';

const _primaryBlue = Color(0xFF1565C0);

/// MVP obrazovka pro úkoly typu Transfer (předání/převzetí bytu).
/// Jednoduché zobrazení dat a tlačítko Dokončit.
class TransferTaskScreen extends ConsumerWidget {
  const TransferTaskScreen({super.key, required this.taskId});

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
          backgroundColor: const Color(0xFFE3F2FD),
          appBar: AppBar(
            title: Text(
              _appBarTitle(detail),
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
                          title: _mainHeading(detail),
                          scheduledStart: detail.scheduledStart,
                        ),
                        const SizedBox(height: 16),
                        _buildAddressWithNavigate(context, detail.apartmentAddress),
                        const SizedBox(height: 16),
                        TaskCountdownTimer(
                          startedAt: detail.startedAt,
                          completedAt: detail.completedAt,
                          estimatedMinutes: parseTaskEstimateMinutes(
                            detail.description,
                            detail.metadata,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // PROČ: Kód schránky a kontakt na hosta – řidič řeší zpoždění a předání klíčů.
                        ..._buildKeyboxAndGuestContact(context, detail),
                        const SizedBox(height: 16),
                        _buildInstructionsCard(context, detail.description, detail.metadata ?? {}),
                        ..._buildTransferMetadata(context, detail.metadata ?? {}),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionButton(context, ref, taskId, detail, 'worker.task_detail_finish_transfer'),
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

  // Dvoufázové odpracování: Nejprve Zahájit (in_progress), poté Dokončit (completed).
  // Uložení přesného UTC času pro sledování reálné doby práce.
  Widget _buildActionButton(BuildContext context, WidgetRef ref, String taskId, dynamic detail, String finishKey) {
    final status = detail?.status ?? '';
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
    if (isInProgress) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () async {
            final result = await maybeShowCashCollectionDialog(
              context,
              ref,
              detail,
              taskId: taskId,
              onCompleted: () {
                ref.invalidate(workerTaskDetailProvider(taskId));
                if (context.mounted) context.pop();
              },
            );
            // Když Cash dialog nebyl zobrazen – potvrzovací dialog zabrání překlikům.
            if (result == null) {
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
            }
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

  /// Kód schránky a kontakt na hosta – řidič musí řešit zpoždění a předání.
  List<Widget> _buildKeyboxAndGuestContact(BuildContext context, dynamic detail) {
    final widgets = <Widget>[];
    final keybox = detail.keybox?.trim();
    final guestName = detail.guestName?.trim();
    final guestPhone = detail.guestPhone?.trim();
    if (keybox != null && keybox.isNotEmpty) {
      widgets.add(_buildKeyboxCard(keybox));
      widgets.add(const SizedBox(height: 12));
    }
    if (guestName != null && guestName.isNotEmpty || guestPhone != null && guestPhone.isNotEmpty) {
      widgets.add(_buildGuestContactCard(context, guestName, guestPhone));
    }
    return widgets;
  }

  Widget _buildKeyboxCard(String keybox) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.key, size: 24, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.label_keybox'.tr(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(keybox, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestContactCard(BuildContext context, String? guestName, String? guestPhone) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (guestName != null && guestName.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.person, size: 24, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'worker.label_guest_name'.tr(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(guestName, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (guestPhone != null && guestPhone.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.phone, size: 24, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'worker.label_guest_phone'.tr(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(guestPhone, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () {
                final tel = guestPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
                launchUrl(Uri.parse('tel:$tel'), mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.phone, size: 20),
              label: Text('worker.guest_call'.tr()),
            ),
          ],
        ],
      ),
    );
  }

  /// AppBar: část PŘED dvojtečkou (např. „Transfer Z letiště“).
  static String _appBarTitle(dynamic detail) {
    final raw = detail.title.isNotEmpty ? detail.title : (detail.apartmentName ?? '—');
    return raw.split(':').first.trim();
  }

  /// Hlavní nadpis: část ZA dvojtečkou, nebo celý název (např. „Petr Sokol“).
  static String _mainHeading(dynamic detail) {
    final raw = detail.title.isNotEmpty ? detail.title : (detail.apartmentName ?? '—');
    return raw.contains(':') ? raw.split(':').sublist(1).join(':').trim() : raw;
  }

  /// Adresa s tlačítkem Navigovat – otevře Google Maps (spolehlivý formát pro iOS i Android).
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

  /// Karta Instrukce / Informace o letu – description + custom_note (číslo letu, jméno klienta).
  Widget _buildInstructionsCard(BuildContext context, String description, Map<String, dynamic> meta) {
    final note = meta['custom_note'];
    final noteText = note is String ? note.trim() : (note?.toString().trim() ?? '');
    final descTrimmed = description.trim();
    final hasContent = descTrimmed.isNotEmpty || noteText.isNotEmpty;
    if (!hasContent) return const SizedBox.shrink();

    final parts = <String>[];
    if (descTrimmed.isNotEmpty) parts.add(descTrimmed);
    if (noteText.isNotEmpty) parts.add(noteText);
    final content = parts.join(parts.length > 1 ? '\n\n' : '');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'worker.instructions_flight_info'.tr(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Text(content, style: TextStyle(fontSize: 16, color: Colors.grey.shade800)),
          ],
        ),
      ),
    );
  }

  /// Otevře Google Maps – univerzální formát pro iOS i Android, Uri.encodeComponent zvládne mezery a diakritiku.
  Future<void> _openMaps(BuildContext context, String address) async {
    final query = address.trim();
    if (query.isEmpty) return;
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Vykreslení metadat pro Transfer: obří banner na peníze (custom_note je již v kartě Instrukce).
  List<Widget> _buildTransferMetadata(BuildContext context, Map<String, dynamic> meta) {
    final widgets = <Widget>[];

    // Vykreslení obřího banneru pro výběr hotovosti.
    final amountRaw = meta['amount_to_collect'];
    final amount = (amountRaw is num) ? amountRaw.toDouble() : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null);
    if (amount != null && amount > 0) {
      widgets.addAll([
        const SizedBox(height: 16),
        _buildAmountBanner(context, amount),
      ]);
    }

    return widgets;
  }

  /// Obří banner na částku k vybrání od hosta (amount_to_collect z metadat).
  /// Dynamické formátování měny podle aktuálního jazyka uživatele (i18n).
  Widget _buildAmountBanner(BuildContext context, num amount) {
    final formatted = NumberFormat.currency(locale: context.locale.toString(), symbol: '€', decimalDigits: 2).format(amount);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade400, width: 2),
      ),
      child: Column(
        children: [
          Text(
            'worker.task_amount_to_collect'.tr(),
            style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            formatted,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
