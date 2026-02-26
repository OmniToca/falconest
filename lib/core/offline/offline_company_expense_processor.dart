import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';

/// Zpracuje frontovanou offline firemní výdaj z MutationQueueService.
///
/// PROČ: Peněženka vyžaduje wallet_id (FK) – offline ho neznáme, protože SELECT
/// na employee_cash_wallets selhává bez sítě. Uložíme do fronty payload s
/// tenant_id, profile_id, amount, note, receipt_image_url. Při processQueue (už online)
/// voláme recordCompanyExpense – ten provede celý flow: najde peněženku,
/// vloží transakci, sníží balance.
Future<void> processOfflineCompanyExpense(Map<String, dynamic> payload) async {
  final tenantId = payload['tenant_id']?.toString();
  final profileId = payload['profile_id']?.toString();
  final amountRaw = payload['amount'];
  final note = (payload['note']?.toString() ?? '').trim();
  if (tenantId == null ||
      tenantId.isEmpty ||
      profileId == null ||
      profileId.isEmpty ||
      note.isEmpty) {
    return;
  }
  final amount = (amountRaw is num)
      ? amountRaw.toDouble()
      : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null);
  if (amount == null || amount <= 0) return;

  final receiptRaw = (payload['receipt_image_url']?.toString() ?? '').trim();
  final receiptImageUrl =
      receiptRaw.isNotEmpty ? receiptRaw : null;

  await CashWalletRepository.instance.recordCompanyExpense(
    tenantId: tenantId,
    profileId: profileId,
    amount: amount,
    note: note,
    receiptImageUrl: receiptImageUrl,
  );
}
