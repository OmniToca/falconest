import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';

/// Zobrazí potvrzovací dialog pro výběr hotovosti při dokončení úkolu.
///
/// Pokud [detail.metadata] obsahuje amount_to_collect > 0, zobrazí dialog.
/// Parametr [forceShowForExtraOnly] umožňuje zobrazit dialog i s plánovanou částkou 0
/// (např. pro úklid – uklízečka může zadat jen extra hotovost).
///
/// Návratová hodnota:
/// - null = dialog nebyl zobrazen (žádná částka a ne forceShow), volající provede běžné dokončení,
/// - true = úkol byl dokončen (ANO nebo NEVYBRAL), volající může zavřít obrazovku,
/// - false = uživatel zrušil, úkol zůstává nedokončený.
///
/// Při potvrzení převzetí se sečte plánovaná částka + zadaná extra částka.
Future<bool?> maybeShowCashCollectionDialog(
  BuildContext context,
  WidgetRef ref,
  dynamic detail, {
  required String taskId,
  required VoidCallback onCompleted,
  bool forceShowForExtraOnly = false,
  bool completeTaskOnConfirm = true,
  List<String>? mediaUrls,
}) async {
  final meta = detail?.metadata;
  if (meta == null || meta is! Map) {
    if (!forceShowForExtraOnly) return null;
  }

  final amountRaw = meta?['amount_to_collect'];
  final plannedAmount = (amountRaw is num)
      ? amountRaw.toDouble()
      : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null) ?? 0;

  if (plannedAmount <= 0 && !forceShowForExtraOnly) return null;

  final formatted = formatTaskAmount(context, ref, plannedAmount);

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CashCollectionDialogContent(
      plannedAmount: plannedAmount,
      formattedPlanned: formatted,
      forceShowForExtraOnly: forceShowForExtraOnly,
      taskId: taskId,
      ref: ref,
      onCompleted: onCompleted,
      completeTaskOnConfirm: completeTaskOnConfirm,
      mediaUrls: mediaUrls,
    ),
  );
}

/// Vnitřní StatefulWidget pro dialog s polem Extra částka.
class _CashCollectionDialogContent extends StatefulWidget {
  const _CashCollectionDialogContent({
    required this.plannedAmount,
    required this.formattedPlanned,
    required this.forceShowForExtraOnly,
    required this.taskId,
    required this.ref,
    required this.onCompleted,
    this.completeTaskOnConfirm = true,
    this.mediaUrls,
  });

  final double plannedAmount;
  final String formattedPlanned;
  final bool forceShowForExtraOnly;
  final String taskId;
  final WidgetRef ref;
  final VoidCallback onCompleted;
  final bool completeTaskOnConfirm;
  final List<String>? mediaUrls;

  @override
  State<_CashCollectionDialogContent> createState() => _CashCollectionDialogContentState();
}

class _CashCollectionDialogContentState extends State<_CashCollectionDialogContent> {
  final _extraController = TextEditingController();

  @override
  void dispose() {
    _extraController.dispose();
    super.dispose();
  }

  double? _parseExtra() {
    final t = _extraController.text.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  Future<void> _onYes() async {
    final extra = _parseExtra() ?? 0;
    final total = widget.plannedAmount + extra;
    if (total <= 0) return;

    final tenantId = widget.ref.read(authNotifierProvider).tenantIdForData;
    final profileId = widget.ref.read(authNotifierProvider).state.profileId;
    if (tenantId == null || tenantId.isEmpty || profileId == null || profileId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.cash_collection_error'.tr(namedArgs: {'error': 'Missing tenant or profile'})),
          ),
        );
      }
      return;
    }

    try {
      await CashWalletRepository.instance.recordCashCollection(
        taskId: widget.taskId,
        amount: total,
        tenantId: tenantId,
        profileId: profileId,
      );
      if (widget.completeTaskOnConfirm) {
        await widget.ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(
              widget.taskId,
              'completed',
              completedAt: DateTime.now().toUtc(),
              mediaUrls: widget.mediaUrls,
            );
      }
      if (mounted) Navigator.of(context).pop(true);
      widget.onCompleted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('worker.cash_collection_confirmed'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('worker.cash_collection_error'.tr(namedArgs: {'error': e.toString()})),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExtraOnly = widget.forceShowForExtraOnly && widget.plannedAmount <= 0;
    final contentText = isExtraOnly
        ? 'worker.cash_collection_extra_only'.tr()
        : 'worker.cash_collection_planned_extra'.tr(namedArgs: {'amount': widget.formattedPlanned});

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('worker.cash_collection_confirm_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(contentText),
          const SizedBox(height: 16),
          TextField(
            controller: _extraController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'worker.cash_collection_extra_label'.tr(),
              hintText: '0',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () async {
                final extra = _parseExtra() ?? 0;
                final total = widget.plannedAmount + extra;
                if (total <= 0) return;
                await _onYes();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('worker.cash_collection_btn_yes'.tr()),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                if (widget.completeTaskOnConfirm) {
                  await widget.ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(
                        widget.taskId,
                        'completed',
                        completedAt: DateTime.now().toUtc(),
                        metadataOverlay: {'cash_collection_failed': true},
                      );
                }
                if (mounted) Navigator.of(context).pop(true);
                widget.onCompleted();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('worker.cash_collection_not_collected'.tr())),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade800,
                side: BorderSide(color: Colors.orange.shade700),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('worker.cash_collection_btn_no'.tr()),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('worker.cash_collection_btn_cancel'.tr()),
            ),
          ],
        ),
      ],
    );
  }
}
