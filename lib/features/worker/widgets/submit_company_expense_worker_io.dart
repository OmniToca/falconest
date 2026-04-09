import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/worker/data/services/worker_sync_service_mobile.dart';

/// Mobil: online zápis + stažení do Driftu; offline optimalistický Drift + fronta se stejným UUID transakce.
Future<void> submitWorkerCompanyExpense({
  required WidgetRef ref,
  required String tenantId,
  required String profileId,
  required double amount,
  required String note,
  String? receiptImageUrl,
  String? apartmentId,
  String? clientId,
}) async {
  try {
    await CashWalletRepository.instance.recordCompanyExpense(
      tenantId: tenantId,
      profileId: profileId,
      amount: amount,
      note: note,
      receiptImageUrl: receiptImageUrl,
      apartmentId: apartmentId,
      clientId: clientId,
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
        rethrow;
      }
      final txId = const Uuid().v4();
      final cash = ref.read(driftEmployeeCashRepositoryProvider);
      await cash.applyCompanyExpenseLocal(
        tenantId: tenantId,
        profileId: profileId,
        walletSupabaseId: wallet.id,
        transactionId: txId,
        amountPositive: amount.abs(),
        note: note,
        receiptImageUrl: receiptImageUrl,
        apartmentId: apartmentId,
        clientId: clientId,
      );
      final noteTrimmed = note.trim();
      await ref.read(mutationQueueServiceProvider).enqueueMutation(
            table: 'employee_cash_transactions',
            action: 'OFFLINE_COMPANY_EXPENSE',
            payload: {
              'tenant_id': tenantId,
              'profile_id': profileId,
              'amount': amount,
              'note': noteTrimmed,
              'transaction_id': txId,
              if (receiptImageUrl != null && receiptImageUrl.trim().isNotEmpty)
                'receipt_image_url': receiptImageUrl.trim(),
              if (apartmentId != null && apartmentId.trim().isNotEmpty)
                'apartment_id': apartmentId.trim(),
              if (clientId != null && clientId.trim().isNotEmpty) 'client_id': clientId.trim(),
            },
          );
      unawaited(
        Future<void>(() async {
          try {
            await ref.read(mutationQueueServiceProvider).processQueue();
          } catch (e, st) {
            AppLogger.error('submitWorkerCompanyExpense: okamžité processQueue po frontě selhalo', e, st);
          }
        }),
      );
      return;
    }
    rethrow;
  }
}
