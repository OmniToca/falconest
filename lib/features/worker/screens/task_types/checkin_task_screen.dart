import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';
import 'package:falconest/features/worker/widgets/task_countdown_timer.dart';
import 'package:falconest/features/worker/widgets/worker_task_shared_header.dart';
import 'package:falconest/features/worker/utils/cash_collection_dialog.dart';
import 'package:falconest/features/worker/widgets/issue_reporter_dialog.dart';
import 'package:falconest/features/worker/widgets/task_complete_with_photo_section.dart';

/// MVP obrazovka pro úkoly typu Check-in.
/// Jednoduché zobrazení dat a tlačítko Dokončit.
class CheckinTaskScreen extends ConsumerWidget {
  const CheckinTaskScreen({super.key, required this.taskId});

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
          backgroundColor: const Color(0xFFFFF3E0),
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
                        WorkerTaskSharedHeader(
                          title: _mainHeading(detail),
                          scheduledStart: detail.scheduledStart,
                          apartmentAddress: detail.apartmentAddress,
                          startedAt: detail.startedAt,
                          completedAt: detail.completedAt,
                          estimatedMinutes: parseTaskEstimateMinutes(
                            detail.description,
                            detail.metadata,
                          ),
                        ),
                        // PROČ: Kód schránky a kontakt na hosta – check-in agent řeší zpoždění a předání klíčů.
                        ..._buildKeyboxAndGuestContact(context, detail),
                        const SizedBox(height: 16),
                        Text(
                          detail.description.isNotEmpty ? detail.description : '—',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        ..._buildCheckinMetadata(context, ref, detail.metadata ?? {}),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TaskCompleteWithPhotoSection(
                  taskId: taskId,
                  detail: detail,
                  finishKey: 'worker.task_detail_finish',
                  beforeComplete: (ctx, ref, mediaUrls, {localPhotoPaths}) =>
                      maybeShowCashCollectionDialog(
                    ctx,
                    ref,
                    detail,
                    taskId: taskId,
                    onCompleted: () {
                      ref.invalidate(workerTaskDetailProvider(taskId));
                      if (ctx.mounted) ctx.pop();
                    },
                    mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
                    localPhotoPaths: localPhotoPaths,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(child: Text('worker.task_detail_not_found'.tr())),
      ),
    );
  }

  /// Kód schránky, jméno a telefon hosta – check-in agent musí řešit zpoždění.
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
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.key, size: 24, color: Colors.orange.shade700),
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
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (guestName != null && guestName.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.person, size: 24, color: Colors.orange.shade700),
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
                Icon(Icons.phone, size: 24, color: Colors.orange.shade700),
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

  static String _appBarTitle(dynamic detail) {
    final raw = detail.title.isNotEmpty ? detail.title : (detail.apartmentName ?? '—');
    final base = raw.split(':').first.trim();
    final ref = detail.referenceNumber?.trim();
    return (ref != null && ref.isNotEmpty) ? '$base • #$ref' : base;
  }

  static String _mainHeading(dynamic detail) {
    final raw = detail.title.isNotEmpty ? detail.title : (detail.apartmentName ?? '—');
    return raw.contains(':') ? raw.split(':').sublist(1).join(':').trim() : raw;
  }

  /// Vykreslení metadat pro Check-in: custom_note (instrukce k předání klíčů), banner na peníze, rozpad platby.
  /// [ref] – pro formatTaskAmount (měna dle tenanta, fallback profil).
  List<Widget> _buildCheckinMetadata(BuildContext context, WidgetRef ref, Map<String, dynamic> meta) {
    final widgets = <Widget>[];

    // Poznámka (instrukce k předání klíčů).
    final note = meta['custom_note'];
    final noteText = note is String ? note.trim() : (note?.toString().trim() ?? '');
    if (noteText.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 16),
        _buildCustomNoteCard(noteText, icon: Icons.key),
      ]);
    }

    // Vykreslení obřího banneru pro výběr hotovosti.
    final amountRaw = meta['amount_to_collect'];
    final amount = (amountRaw is num) ? amountRaw.toDouble() : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null);
    if (amount != null && amount > 0) {
      widgets.addAll([
        const SizedBox(height: 16),
        _buildAmountBanner(context, ref, amount),
      ]);
    }

    // Detailní rozpad platby (collection_breakdown) – klíče přeloženy přes admin.task_type_*.
    final breakdown = meta['collection_breakdown'];
    if (breakdown is Map && breakdown.isNotEmpty) {
      widgets.addAll([
        const SizedBox(height: 12),
        _buildBreakdownCard(context, ref, breakdown),
      ]);
    }

    return widgets;
  }

  Widget _buildCustomNoteCard(String text, {IconData icon = Icons.note_outlined}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.custom_note'.tr(),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Text(text, style: TextStyle(fontSize: 16, color: Colors.grey.shade800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sjednocené formátování přes formatTaskAmount – měna dle tenanta, fallback profil uživatele.
  Widget _buildAmountBanner(BuildContext context, WidgetRef ref, num amount) {
    final formatted = formatTaskAmount(context, ref, amount);
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
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
          ),
        ],
      ),
    );
  }

  /// Sjednocené formátování přes formatTaskAmount – měna dle tenanta, fallback profil uživatele.
  Widget _buildBreakdownCard(BuildContext context, WidgetRef ref, Map<dynamic, dynamic> map) {
    final parts = <Widget>[];
    for (final e in map.entries) {
      final key = e.key.toString().toLowerCase().replaceAll('-', '_');
      final label = _translateTaskTypeKey(key);
      final v = e.value;
      final amountEur = (v is num) ? v.toDouble() : (double.tryParse(v?.toString() ?? '0') ?? 0);
      final formatted = formatTaskAmount(context, ref, amountEur);
      parts.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
            Text(formatted, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          ],
        ),
      ));
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'worker.collection_breakdown'.tr(),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          ...parts,
        ],
      ),
    );
  }

  String _translateTaskTypeKey(String key) {
    final candidate = 'admin.task_type_$key';
    final translated = candidate.tr();
    return translated == candidate ? 'admin.task_type_other'.tr() : translated;
  }
}
