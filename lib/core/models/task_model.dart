/// Model záznamu tabulky [tasks] – úkol (API/JSON DTO).
///
/// Pro formuláře, API volání a konzistenci při práci s úkoly z Supabase.
/// apartmentId je nullable – u externích úkolů bez bytu (client_id, custom_location, custom_title).
/// Offline model pro Isar viz [TaskLocal] v core/database/models.
class TaskModel {
  const TaskModel({
    required this.id,
    required this.tenantId,
    this.referenceNumber,
    this.apartmentId,
    this.clientId,
    this.customLocation,
    this.customTitle,
    this.assignedTo,
    this.assignedUserIds = const [],
    required this.scheduledStart,
    required this.status,
    this.photoUrl,
    this.title,
    this.description,
    this.taskType,
    this.reservationId,
    this.serviceId,
    this.metadata,
    this.createdBy,
    this.deletedAt,
    this.invoicedAt,
    this.localUpdatedAt,
  });

  final String id;
  final String tenantId;
  /// Referenční číslo úkolu (např. TSK-X7M2P4). Lidsky čitelný identifikátor pro podporu.
  final String? referenceNumber;
  /// Null u úkolů na úrovni agentury nebo externích úkolů bez bytu.
  final String? apartmentId;
  /// Pro externí úkoly bez bytu – vazba na klienta pro fakturaci.
  final String? clientId;
  /// Adresa pro řidiče/personál u úkolů bez bytu.
  final String? customLocation;
  /// Název úkolu, např. "Transfer letiště", když nemáme název bytu.
  final String? customTitle;
  final String? assignedTo;
  /// Další přiřazení pracovníci – pro sdílení úkolu a dělení odměny.
  final List<String> assignedUserIds;
  final DateTime scheduledStart;
  final String status;
  final String? photoUrl;
  final String? title;
  final String? description;
  final String? taskType;
  final String? reservationId;
  final String? serviceId;
  final Map<String, dynamic>? metadata;
  final String? createdBy;
  final DateTime? deletedAt;
  final DateTime? invoicedAt;
  final DateTime? localUpdatedAt;

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc();
      return null;
    }

    DateTime parseRequiredDateTime(dynamic raw) {
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    Map<String, dynamic>? parseMetadata(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    }

    String? optString(dynamic v) {
      final s = (v?.toString() ?? '').trim();
      return s.isEmpty ? null : s;
    }

    List<String> parseStringList(dynamic raw) {
      if (raw == null) return const [];
      if (raw is List) {
        return raw
            .map((e) => e?.toString().trim())
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toList();
      }
      return const [];
    }

    final rawStart = json['scheduled_start'] ?? json['due_date'];

    return TaskModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      referenceNumber: optString(json['reference_number']),
      apartmentId: optString(json['apartment_id']),
      clientId: optString(json['client_id']),
      customLocation: optString(json['custom_location']),
      customTitle: optString(json['custom_title']),
      assignedTo: optString(json['assigned_to']),
      assignedUserIds: parseStringList(json['assigned_user_ids']),
      scheduledStart: parseRequiredDateTime(rawStart),
      status: (json['status'] as String?)?.trim() ?? 'pending',
      photoUrl: optString(json['photo_url']),
      title: optString(json['title']),
      description: optString(json['description']),
      taskType: optString(json['task_type']),
      reservationId: optString(json['reservation_id']),
      serviceId: optString(json['service_id']),
      metadata: parseMetadata(json['metadata']),
      createdBy: optString(json['created_by']),
      deletedAt: parseDateTime(json['deleted_at']),
      invoicedAt: parseDateTime(json['invoiced_at']),
      localUpdatedAt: parseDateTime(json['local_updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (apartmentId != null) 'apartment_id': apartmentId,
      if (clientId != null) 'client_id': clientId,
      if (customLocation != null) 'custom_location': customLocation,
      if (customTitle != null) 'custom_title': customTitle,
      if (assignedTo != null) 'assigned_to': assignedTo,
      if (assignedUserIds.isNotEmpty) 'assigned_user_ids': assignedUserIds,
      'scheduled_start': scheduledStart.toIso8601String(),
      'status': status,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (taskType != null) 'task_type': taskType,
      if (reservationId != null) 'reservation_id': reservationId,
      if (serviceId != null) 'service_id': serviceId,
      if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
      if (createdBy != null) 'created_by': createdBy,
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
      if (invoicedAt != null) 'invoiced_at': invoicedAt!.toIso8601String(),
      if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt!.toIso8601String(),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) => TaskModel.fromJson(map);

  /// Unikátní spojení assignedTo (pokud existuje) a prvků z assignedUserIds.
  List<String> get allAssignees {
    final ids = <String>{};
    if (assignedTo != null && assignedTo!.isNotEmpty) ids.add(assignedTo!);
    ids.addAll(assignedUserIds);
    return ids.toList();
  }

  TaskModel copyWith({
    String? id,
    String? tenantId,
    String? referenceNumber,
    String? apartmentId,
    String? clientId,
    String? customLocation,
    String? customTitle,
    String? assignedTo,
    List<String>? assignedUserIds,
    DateTime? scheduledStart,
    String? status,
    String? photoUrl,
    String? title,
    String? description,
    String? taskType,
    String? reservationId,
    String? serviceId,
    Map<String, dynamic>? metadata,
    String? createdBy,
    DateTime? deletedAt,
    DateTime? invoicedAt,
    DateTime? localUpdatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      apartmentId: apartmentId ?? this.apartmentId,
      clientId: clientId ?? this.clientId,
      customLocation: customLocation ?? this.customLocation,
      customTitle: customTitle ?? this.customTitle,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      taskType: taskType ?? this.taskType,
      reservationId: reservationId ?? this.reservationId,
      serviceId: serviceId ?? this.serviceId,
      metadata: metadata ?? this.metadata,
      createdBy: createdBy ?? this.createdBy,
      deletedAt: deletedAt ?? this.deletedAt,
      invoicedAt: invoicedAt ?? this.invoicedAt,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }
}
