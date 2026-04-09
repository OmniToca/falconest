import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/worker/data/services/worker_sync_service_mobile.dart';

/// Mobil: po úspěchu stáhne peněženku do Driftu; při výpadku sítě optimalistický zápis, pokud známe [walletId] z lokální DB.
Future<void> recordWorkerCashCollectionAfterConfirm({
  required WidgetRef ref,
  required String taskId,
  required double amount,
  required String tenantId,
  required String profileId,
  double? expectedAmount,
  String? note,
}) async {
  try {
    await CashWalletRepository.instance.recordCashCollection(
      taskId: taskId,
      amount: amount,
      tenantId: tenantId,
      profileId: profileId,
      expectedAmount: expectedAmount,
      note: note,
      deferOfflineQueue: true,
    );
    await WorkerSyncService.pullEmployeeCashToDrift(
      tenantId,
      profileId,
      ref.read(driftSyncReposProvider),
    );
  } catch (e) {
    if (MutationQueueService.isNetworkError(e)) {
      final wallet = ref.read(myCashWalletProvider).valueOrNull;
      if (wallet == null || wallet.id.isEmpty) {
        await ref.read(mutationQueueServiceProvider).enqueueMutation(
              table: 'employee_cash_transactions',
              action: 'OFFLINE_CASH_COLLECTION',
              payload: {
                'tenant_id': tenantId,
                'profile_id': profileId,
                'task_id': taskId,
                'amount': amount,
                if (expectedAmount != null && expectedAmount > 0) 'expected_amount': expectedAmount,
                if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
              },
            );
        unawaited(
          Future<void>(() async {
            try {
              await ref.read(mutationQueueServiceProvider).processQueue();
            } catch (e, st) {
              AppLogger.error('recordWorkerCashCollectionAfterConfirm: processQueue (bez walletId) selhalo', e, st);
            }
          }),
        );
        return;
      }

      final txId = const Uuid().v4();
      final cash = ref.read(driftEmployeeCashRepositoryProvider);
      await cash.applyCashCollectionLocal(
        tenantId: tenantId,
        profileId: profileId,
        walletSupabaseId: wallet.id,
        taskId: taskId,
        amount: amount,
        transactionId: txId,
        expectedAmount: expectedAmount,
        note: note,
      );

      await ref.read(mutationQueueServiceProvider).enqueueMutation(
            table: 'employee_cash_transactions',
            action: 'OFFLINE_CASH_COLLECTION',
            payload: {
              'tenant_id': tenantId,
              'profile_id': profileId,
              'task_id': taskId,
              'amount': amount,
              if (expectedAmount != null && expectedAmount > 0) 'expected_amount': expectedAmount,
              if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
              'transaction_id': txId,
            },
          );
      unawaited(
        Future<void>(() async {
          try {
            await ref.read(mutationQueueServiceProvider).processQueue();
          } catch (e, st) {
            AppLogger.error('recordWorkerCashCollectionAfterConfirm: processQueue po lokální hotovosti selhalo', e, st);
          }
        }),
      );
      return;
    }
    rethrow;
  }
}
