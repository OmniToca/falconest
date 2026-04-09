import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';

/// Web: firemní výdaj přímo přes [CashWalletRepository] (Supabase).
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
  await CashWalletRepository.instance.recordCompanyExpense(
    tenantId: tenantId,
    profileId: profileId,
    amount: amount,
    note: note,
    receiptImageUrl: receiptImageUrl,
    apartmentId: apartmentId,
    clientId: clientId,
  );
}
