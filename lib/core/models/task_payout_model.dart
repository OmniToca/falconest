/// Model záznamu tabulky [task_payouts] – výplata pracovníkovi z úkolu.
///
/// Prémiový modul „Vyúčtování a Provize“ (Settlements & Commissions).
/// Oddělený od Podkladů pro fakturaci – řeší výdaje agentury: výplaty zaměstnancům.
class TaskPayoutModel {
  const TaskPayoutModel({
    required this.id,
    required this.tenantId,
    required this.taskId,
    required this.profileId,
    required this.amount,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String taskId;
  final String profileId;
  final num amount;
  /// pending = čeká na schválení, approved = schváleno, paid = vyplaceno
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TaskPayoutModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic raw) {
      if (raw == null) return DateTime.now().toUtc();
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    return TaskPayoutModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      amount: (json['amount'] as num?) ?? 0,
      status: (json['status'] as String?)?.trim() ?? 'pending',
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'task_id': taskId,
      'profile_id': profileId,
      'amount': amount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TaskPayoutModel.fromMap(Map<String, dynamic> map) =>
      TaskPayoutModel.fromJson(map);

  TaskPayoutModel copyWith({
    String? id,
    String? tenantId,
    String? taskId,
    String? profileId,
    num? amount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskPayoutModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      taskId: taskId ?? this.taskId,
      profileId: profileId ?? this.profileId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
