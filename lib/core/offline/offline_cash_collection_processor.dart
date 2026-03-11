import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';

/// Zpracuje frontovanou offline cash collection z MutationQueueService.
///
/// PROČ: Peněženka vyžaduje wallet_id (FK) – offline ho neznáme, protože SELECT
/// na employee_cash_wallets selhává bez sítě. Uložíme do fronty payload s
/// tenant_id, profile_id, task_id, amount, expected_amount. Při processQueue (už online)
/// voláme recordCashCollection – ten provede celý flow: najde/vytvoří peněženku,
/// vloží transakci, aktualizuje balance.
Future<void> processOfflineCashCollection(Map<String, dynamic> payload) async {
  final tenantId = payload['tenant_id']?.toString();
  final profileId = payload['profile_id']?.toString();
  final taskId = payload['task_id']?.toString();
  final amountRaw = payload['amount'];
  if (tenantId == null ||
      tenantId.isEmpty ||
      profileId == null ||
      profileId.isEmpty ||
      taskId == null ||
      taskId.isEmpty) {
    return;
  }
  final amount = (amountRaw is num)
      ? amountRaw.toDouble()
      : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null);
  if (amount == null || amount <= 0) return;

  // PROČ: expected_amount pro výpočet spropitného – uloží se do transakce při sync.
  final expectedRaw = payload['expected_amount'];
  final expectedAmount = (expectedRaw is num)
      ? expectedRaw.toDouble()
      : (expectedRaw != null ? double.tryParse(expectedRaw.toString()) : null);

  final note = payload['note']?.toString().trim();

  await CashWalletRepository.instance.recordCashCollection(
    tenantId: tenantId,
    profileId: profileId,
    taskId: taskId,
    amount: amount,
    expectedAmount: (expectedAmount != null && expectedAmount > 0) ? expectedAmount : null,
    note: (note != null && note.isNotEmpty) ? note : null,
  );
}
