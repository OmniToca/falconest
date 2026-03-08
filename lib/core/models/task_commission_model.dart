/// Model záznamu tabulky [task_commissions] – provize externímu partnerovi z úkolu.
///
/// Prémiový modul „Vyúčtování a Provize“ (Settlements & Commissions).
/// Oddělený od Podkladů pro fakturaci – řeší výdaje agentury: provize externím partnerům.
class TaskCommissionModel {
  const TaskCommissionModel({
    required this.id,
    required this.tenantId,
    required this.taskId,
    this.clientId,
    this.profileId,
    required this.amount,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String taskId;
  /// Externí agentura/partner – vyplněno když příjemce je klient (client_id).
  final String? clientId;
  /// Zaměstnanec – vyplněno když příjemce je náš pracovník (profile_id).
  final String? profileId;
  final num amount;
  /// pending = čeká na schválení, approved = schváleno, paid = vyplaceno
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TaskCommissionModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic raw) {
      if (raw == null) return DateTime.now().toUtc();
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    final clientRaw = json['client_id'];
    final profileRaw = json['profile_id'];
    final clientId = (clientRaw is String? && clientRaw != null && clientRaw.trim().isNotEmpty)
        ? clientRaw.trim()
        : null;
    final profileId = (profileRaw is String? && profileRaw != null && profileRaw.trim().isNotEmpty)
        ? profileRaw.trim()
        : null;

    return TaskCommissionModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      clientId: clientId,
      profileId: profileId,
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
      if (clientId != null) 'client_id': clientId,
      if (profileId != null) 'profile_id': profileId,
      'amount': amount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TaskCommissionModel.fromMap(Map<String, dynamic> map) =>
      TaskCommissionModel.fromJson(map);

  TaskCommissionModel copyWith({
    String? id,
    String? tenantId,
    String? taskId,
    String? clientId,
    String? profileId,
    num? amount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskCommissionModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      taskId: taskId ?? this.taskId,
      clientId: clientId ?? this.clientId,
      profileId: profileId ?? this.profileId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
