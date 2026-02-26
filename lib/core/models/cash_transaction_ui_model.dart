/// UI model transakce zaměstnanecké pokladny obohacený o kontext z úkolů.
///
/// PROČ: Supabase stream vrací pouze surová data tabulky employee_cash_transactions.
/// Kontext (apartmán, host) se načítá z tasks s joiny na apartments/reservations.
/// BACKWARD COMPATIBILITY: apartmentName a guestName jsou nullable – staré záznamy
/// bez task_id je nemají.
class CashTransactionUIModel {
  const CashTransactionUIModel({
    required this.raw,
    this.apartmentName,
    this.guestName,
  });

  /// Surová data transakce z employee_cash_transactions.
  final Map<String, dynamic> raw;

  /// Název apartmánu z tasks.apartment_id → apartments.name (pro výběr od hosta).
  final String? apartmentName;

  /// Jméno hosta z tasks.reservation_id → reservations.guest_name (pro výběr od hosta).
  final String? guestName;

  String? get transactionType => (raw['transaction_type'] as String?)?.trim();
  String? get note => (raw['note'] as String?)?.trim();
  String? get receiptImageUrl =>
      (raw['receipt_image_url'] as String?)?.trim().isNotEmpty == true
          ? (raw['receipt_image_url'] as String).trim()
          : null;
  dynamic get createdAt => raw['created_at'];
  String? get taskId => (raw['task_id'] as String?)?.trim().isNotEmpty == true
      ? (raw['task_id'] as String).trim()
      : null;

  /// Vrací true, pokud má transakce dostatečný kontext pro zobrazení apartmánu a hosta.
  bool get hasTaskContext =>
      (apartmentName != null && apartmentName!.isNotEmpty) ||
      (guestName != null && guestName!.isNotEmpty);
}
