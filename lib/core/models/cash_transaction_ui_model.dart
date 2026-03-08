/// UI model transakce zaměstnanecké pokladny obohacený o kontext z úkolů a klientů.
///
/// PROČ: Supabase stream vrací pouze surová data tabulky employee_cash_transactions.
/// Kontext (apartmán, host) se načítá z tasks s joiny na apartments/reservations.
/// Kontext klienta (jméno, typ) se načítá z clients při vyplněném client_id.
/// BACKWARD COMPATIBILITY: apartmentName, guestName, clientName jsou nullable – staré záznamy je nemají.
class CashTransactionUIModel {
  const CashTransactionUIModel({
    required this.raw,
    this.apartmentName,
    this.guestName,
    this.taskTitle,
    this.clientName,
    this.clientType,
  });

  /// Surová data transakce z employee_cash_transactions.
  final Map<String, dynamic> raw;

  /// Název apartmánu z tasks.apartment_id → apartments.name (pro výběr od hosta).
  final String? apartmentName;

  /// Jméno hosta z tasks.reservation_id → reservations.guest_name (pro výběr od hosta).
  final String? guestName;

  /// Název úkolu z tasks.title (pro bohatší výpis v detailu peněženky).
  final String? taskTitle;

  /// Jméno klienta z clients.name – pro transakce s vazbou na klienta (např. externí transfer).
  final String? clientName;

  /// Typ klienta z clients.client_type (owner, external, agency) – pro zobrazení badge v UI.
  final String? clientType;

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

  /// ID klienta – pro transakce vázané na klienta (např. externí platba).
  String? get clientId => (raw['client_id'] as String?)?.trim().isNotEmpty == true
      ? (raw['client_id'] as String).trim()
      : null;

  /// Očekávaná částka z metadata.amount_to_collect – pro výpočet spropitného/nedoplatku.
  /// NULL = starý záznam nebo transakce bez očekávané částky.
  double? get expectedAmount {
    final v = raw['expected_amount'];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Vrací true, pokud má transakce dostatečný kontext pro zobrazení apartmánu a hosta.
  bool get hasTaskContext =>
      (apartmentName != null && apartmentName!.isNotEmpty) ||
      (guestName != null && guestName!.isNotEmpty);

  /// Vrací true, pokud má transakce vazbu na klienta (např. externí platba).
  bool get hasClientContext =>
      (clientName != null && clientName!.isNotEmpty) ||
      (clientType != null && clientType!.isNotEmpty);

  CashTransactionUIModel copyWith({
    Map<String, dynamic>? raw,
    String? apartmentName,
    String? guestName,
    String? taskTitle,
    String? clientName,
    String? clientType,
  }) {
    return CashTransactionUIModel(
      raw: raw ?? Map<String, dynamic>.from(this.raw),
      apartmentName: apartmentName ?? this.apartmentName,
      guestName: guestName ?? this.guestName,
      taskTitle: taskTitle ?? this.taskTitle,
      clientName: clientName ?? this.clientName,
      clientType: clientType ?? this.clientType,
    );
  }
}
