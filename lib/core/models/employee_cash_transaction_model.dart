/// Model transakce Zaměstnanecké pokladny z tabulky [employee_cash_transactions].
///
/// Reprezentuje jeden záznam účetní knihy: výběr od hosta (COLLECTED_FROM_GUEST),
/// odevzdání agentuře (HANDED_TO_AGENCY) nebo firemní výdaj (COMPANY_EXPENSE).
class EmployeeCashTransactionModel {
  const EmployeeCashTransactionModel({
    required this.id,
    required this.tenantId,
    required this.walletId,
    this.taskId,
    this.apartmentId,
    this.clientId,
    this.expectedAmount,
    required this.amount,
    required this.transactionType,
    this.note,
    this.receiptImageUrl,
    required this.createdBy,
    this.createdAt,
  });

  final String id;
  final String tenantId;
  final String walletId;
  final String? taskId;
  /// Vazba na apartmán u firemních výdajů – pro stržení nákladů ve faktuře majitele.
  final String? apartmentId;
  /// Vazba na klienta – pro platby nesouvisející s apartmánem (např. externí transfer).
  final String? clientId;
  /// Očekávaná částka z metadata.amount_to_collect – pro výpočet spropitného/nedoplatku.
  final double? expectedAmount;
  final double amount;
  final String transactionType;
  /// Poznámka k firemnímu výdaji (např. „Materiál na úklid“).
  final String? note;
  /// URL fotky účtenky v Supabase Storage.
  final String? receiptImageUrl;
  final String createdBy;
  final DateTime? createdAt;

  factory EmployeeCashTransactionModel.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final raw = json['created_at'];
    if (raw != null) {
      if (raw is DateTime) {
        createdAt = raw.toUtc();
      } else if (raw is String) {
        createdAt = DateTime.tryParse(raw)?.toUtc();
      }
    }

    final amountRaw = json['amount'];
    final amount = (amountRaw is num)
        ? amountRaw.toDouble()
        : (amountRaw != null ? double.tryParse(amountRaw.toString()) : null) ?? 0.0;

    final expectedRaw = json['expected_amount'];
    final expectedAmount = (expectedRaw is num)
        ? expectedRaw.toDouble()
        : (expectedRaw != null ? double.tryParse(expectedRaw.toString()) : null);

    return EmployeeCashTransactionModel(
      id: (json['id'] as String?) ?? '',
      tenantId: (json['tenant_id'] as String?) ?? '',
      walletId: (json['wallet_id'] as String?) ?? '',
      taskId: (json['task_id'] as String?)?.trim().isNotEmpty == true
          ? (json['task_id'] as String).trim()
          : null,
      apartmentId: (json['apartment_id'] as String?)?.trim().isNotEmpty == true
          ? (json['apartment_id'] as String).trim()
          : null,
      clientId: (json['client_id'] as String?)?.trim().isNotEmpty == true
          ? (json['client_id'] as String).trim()
          : null,
      expectedAmount: expectedAmount,
      amount: amount,
      transactionType: (json['transaction_type'] as String?) ?? '',
      note: (json['note'] as String?)?.trim().isNotEmpty == true
          ? (json['note'] as String).trim()
          : null,
      receiptImageUrl: (json['receipt_image_url'] as String?)?.trim().isNotEmpty == true
          ? (json['receipt_image_url'] as String).trim()
          : null,
      createdBy: (json['created_by'] as String?) ?? '',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'wallet_id': walletId,
      if (taskId != null) 'task_id': taskId,
      if (apartmentId != null) 'apartment_id': apartmentId,
      if (clientId != null) 'client_id': clientId,
      if (expectedAmount != null) 'expected_amount': expectedAmount,
      'amount': amount,
      'transaction_type': transactionType,
      if (note != null) 'note': note,
      if (receiptImageUrl != null) 'receipt_image_url': receiptImageUrl,
      'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  EmployeeCashTransactionModel copyWith({
    String? id,
    String? tenantId,
    String? walletId,
    String? taskId,
    String? apartmentId,
    String? clientId,
    double? expectedAmount,
    double? amount,
    String? transactionType,
    String? note,
    String? receiptImageUrl,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return EmployeeCashTransactionModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      walletId: walletId ?? this.walletId,
      taskId: taskId ?? this.taskId,
      apartmentId: apartmentId ?? this.apartmentId,
      clientId: clientId ?? this.clientId,
      expectedAmount: expectedAmount ?? this.expectedAmount,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      note: note ?? this.note,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
