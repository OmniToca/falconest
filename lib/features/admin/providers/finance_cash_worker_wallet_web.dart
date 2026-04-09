import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/cash_transaction_ui_model.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/features/admin/providers/finance_cash_enrich_supabase.dart';

/// Web: peněženka workera přes Supabase Realtime (Drift na klientovi není).
final myCashWalletProvider = StreamProvider<EmployeeCashWalletRow?>((ref) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  final profileId = ref.watch(authNotifierProvider).state.profileId;
  if (tenantId == null || tenantId.isEmpty || profileId == null || profileId.isEmpty) {
    yield null;
    return;
  }

  await for (final rawList in CashWalletRepository.instance.watchWalletsRaw(tenantId)) {
    final match = rawList.cast<Map<String, dynamic>>().where((raw) {
      final pid = (raw['profile_id'] as String?)?.trim() ?? '';
      return pid == profileId;
    }).toList();
    if (match.isEmpty) {
      yield null;
      continue;
    }
    final raw = match.first;
    yield EmployeeCashWalletRow(
      id: (raw['id'] as String?)?.trim() ?? '',
      profileId: (raw['profile_id'] as String?)?.trim() ?? '',
      balance: _toDouble(raw['balance']) ?? 0,
      workerName: '',
    );
  }
});

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// Web: transakce přes Realtime + obohacení přes Supabase dotazy na tasks/clients.
final myCashTransactionsProvider = StreamProvider<List<CashTransactionUIModel>>((ref) async* {
  final walletAsync = ref.watch(myCashWalletProvider);
  final wallet = walletAsync.valueOrNull;
  if (wallet == null || wallet.id.isEmpty) {
    yield [];
    return;
  }

  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  await for (final rows in CashWalletRepository.instance.watchTransactionsRawForWallet(
    tenantId,
    wallet.id,
  )) {
    yield await enrichCashTransactionsWithSupabase(tenantId, rows);
  }
});
