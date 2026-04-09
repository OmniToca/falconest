/// Model notifikace z tabulky [notifications].
///
/// Reprezentuje jeden záznam oznámení určeného konkrétnímu uživateli (profile_id)
/// v rámci agentury (tenant_id). Pole [createdAt] slouží pro řazení a případnou
/// konflikt resolution při offline sync (zatím notifikace pouze z Supabase Realtime).
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.tenantId,
    required this.profileId,
    required this.title,
    required this.message,
    this.type,
    this.isRead = false,
    this.createdAt,
    this.metadata,
  });

  final String id;
  final String tenantId;
  final String profileId;
  final String title;
  final String message;
  /// Typ notifikace – 'alert', 'system', 'task' atd. Pro budoucí filtr a styling.
  final String? type;
  /// Zda uživatel notifikaci přečetl.
  final bool isRead;
  /// Čas vytvoření (UTC). Pro řazení a timestamp merging.
  final DateTime? createdAt;
  /// Volitelná data z DB (např. `task_id` pro navigaci na detail úkolu).
  final Map<String, dynamic>? metadata;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final raw = json['created_at'];
    if (raw != null) {
      if (raw is DateTime) {
        createdAt = raw.toUtc();
      } else if (raw is String) {
        createdAt = DateTime.tryParse(raw)?.toUtc();
      }
    }

    final rawIsRead = json['is_read'];
    final isRead = rawIsRead == true || rawIsRead == 1;

    Map<String, dynamic>? meta;
    final rawMeta = json['metadata'];
    if (rawMeta is Map) {
      meta = Map<String, dynamic>.from(rawMeta);
    }

    return NotificationModel(
      id: (json['id'] as String?) ?? '',
      tenantId: (json['tenant_id'] as String?) ?? '',
      profileId: (json['profile_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      type: (json['type'] as String?)?.trim().isNotEmpty == true
          ? (json['type'] as String).trim()
          : null,
      isRead: isRead,
      createdAt: createdAt,
      metadata: meta,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'profile_id': profileId,
      'title': title,
      'message': message,
      if (type != null) 'type': type,
      'is_read': isRead,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Kopie s aktualizovaným isRead – pro lokální stav po markAsRead.
  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      tenantId: tenantId,
      profileId: profileId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      metadata: metadata,
    );
  }
}
