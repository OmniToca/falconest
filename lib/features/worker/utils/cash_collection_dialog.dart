import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';

/// Zobrazí potvrzovací dialog pro výběr hotovosti při dokončení úkolu.
///
/// Pokud [detail.metadata] obsahuje amount_to_collect > 0, zobrazí dialog.
/// Návratová hodnota:
/// - null = dialog nebyl zobrazen (žádná částka), volající provede běžné dokončení,
/// - true = úkol byl dokončen (ANO nebo NEVYBRAL), volající může zavřít obrazovku,
/// - false = uživatel zrušil, úkol zůstává nedokončený.
///
/// Pokud zaměstnanec potvrdí převzetí, peníze se mu přičtou do jeho dlužné peněženky.
Future<bool?> maybeShowCashCollectionDialog(
  BuildContext context,
  WidgetRef ref,
  dynamic detail, {
  required String taskId,
  required VoidCallback onCompleted,
}) async {
  final meta = detail?.metadata;
  if (meta == null || meta is! Map) return null;

  final amountRaw = meta['amount_to_collect'];
  final amount = (amountRaw is num)
      ? amountRaw.toDouble()
      : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null);
  if (amount == null || amount <= 0) return null;

  final formatted = NumberFormat.currency(
    locale: context.locale.toString(),
    symbol: '€',
    decimalDigits: 2,
  ).format(amount);

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('worker.cash_collection_confirm_title'.tr()),
      content: Text(
        'worker.cash_collection_confirm_message'.tr(namedArgs: {'amount': formatted}),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actions: [
        // Tlačítka vertikálně pro mobilní přehlednost.
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hlavní akce – ANO
            FilledButton(
              onPressed: () async {
                final tenantId = ref.read(authNotifierProvider).tenantIdForData;
                final profileId = ref.read(authNotifierProvider).state.profileId;
                if (tenantId == null || tenantId.isEmpty || profileId == null || profileId.isEmpty) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('worker.cash_collection_error'.tr(namedArgs: {'error': 'Missing tenant or profile'}))),
                    );
                  }
                  return;
                }
                try {
                  await CashWalletRepository.instance.recordCashCollection(
                    taskId: taskId,
                    amount: amount,
                    tenantId: tenantId,
                    profileId: profileId,
                  );
                  await ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(
                        taskId,
                        'completed',
                        completedAt: DateTime.now().toUtc(),
                      );
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                  onCompleted();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('worker.cash_collection_confirmed'.tr())),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('worker.cash_collection_error'.tr(namedArgs: {'error': e.toString()}))),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('worker.cash_collection_btn_yes'.tr()),
            ),
            const SizedBox(height: 10),
            // 2. Alternativa – NE (nestandardní situace)
            OutlinedButton(
              onPressed: () async {
                await ref.read(workerTaskStatusNotifierProvider.notifier).updateStatus(
                      taskId,
                      'completed',
                      completedAt: DateTime.now().toUtc(),
                      metadataOverlay: {'cash_collection_failed': true},
                    );
                if (ctx.mounted) Navigator.of(ctx).pop(true);
                onCompleted();
                if (context.mounted) {
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
            // 3. Zrušit
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('worker.cash_collection_btn_cancel'.tr()),
            ),
          ],
        ),
      ],
    ),
  );
}
