import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';

/// Web: výběr hotovosti – repository sama zařadí frontu při síťové chybě.
Future<void> recordWorkerCashCollectionAfterConfirm({
  required WidgetRef ref,
  required String taskId,
  required double amount,
  required String tenantId,
  required String profileId,
  double? expectedAmount,
  String? note,
}) async {
  await CashWalletRepository.instance.recordCashCollection(
    taskId: taskId,
    amount: amount,
    tenantId: tenantId,
    profileId: profileId,
    expectedAmount: expectedAmount,
    note: note,
  );
}
