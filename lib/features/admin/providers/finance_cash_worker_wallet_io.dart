import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/database/drift/repositories/drift_employee_cash_repository.dart';
import 'package:falconest/core/models/cash_transaction_ui_model.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/features/admin/providers/finance_cash_enrich_drift.dart';

/// Peněženka přihlášeného workera z Driftu.
///
/// PROČ: Mobil nesmí číst `employee_cash_wallets` ze Supabase streamu; stav přijde při synci
/// a okamžitě se aktualizuje po lokálním zápisu (výdaj / výběr).
final myCashWalletProvider = StreamProvider<EmployeeCashWalletRow?>((ref) {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  final profileId = ref.watch(authNotifierProvider).state.profileId;
  if (tenantId == null || tenantId.isEmpty || profileId == null || profileId.isEmpty) {
    return Stream.value(null);
  }
  final repo = ref.watch(driftEmployeeCashRepositoryProvider);
  return repo.watchWalletForProfile(tenantId, profileId).map((w) {
    if (w == null) return null;
    return EmployeeCashWalletRow(
      id: w.supabaseId,
      profileId: w.profileId,
      balance: w.balance,
      workerName: '',
    );
  });
});

/// Historie transakcí vlastní peněženky – Drift + obohacení z lokálních úkolů/klientů.
final myCashTransactionsProvider = StreamProvider<List<CashTransactionUIModel>>((ref) {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  final profileId = ref.watch(authNotifierProvider).state.profileId;
  if (tenantId == null || tenantId.isEmpty || profileId == null || profileId.isEmpty) {
    return Stream.value(const []);
  }
  final repo = ref.watch(driftEmployeeCashRepositoryProvider);
  return repo.watchWalletBundleForProfile(tenantId, profileId).asyncMap((bundle) async {
    if (bundle.wallet == null) return <CashTransactionUIModel>[];
    final rawMaps = bundle.txs
        .map(DriftEmployeeCashRepository.transactionToRawMap)
        .toList();
    return enrichCashTransactionsFromDrift(ref, tenantId, rawMaps);
  });
});
