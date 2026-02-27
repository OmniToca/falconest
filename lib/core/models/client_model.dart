/// Model záznamu tabulky [clients] – zákazník agentury (CRM).
///
/// Slouží pro externí úkoly bez apartmánu – např. transfery pro cizí lidi,
/// fakturace klientovi. client_type: owner (majitel), external (externí klient), agency (agentura).
class ClientModel {
  const ClientModel({
    required this.id,
    required this.tenantId,
    required this.name,
    this.email,
    this.phone,
    this.clientType,
    this.profileId,
    this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? email;
  final String? phone;
  /// Typ klienta: owner, external, agency.
  final String? clientType;
  /// Propojení s přihlašovacím profilem (profiles.id) – pro Klientský portál majitelů.
  /// NULL = klient nemá přístup do systému, pouze záznam v CRM.
  final String? profileId;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc();
      return null;
    }

    return ClientModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim().isNotEmpty == true
          ? (json['email'] as String).trim()
          : null,
      phone: (json['phone'] as String?)?.trim().isNotEmpty == true
          ? (json['phone'] as String).trim()
          : null,
      clientType: (json['client_type'] as String?)?.trim().isNotEmpty == true
          ? (json['client_type'] as String).trim()
          : null,
      profileId: (json['profile_id'] as String?)?.trim().isNotEmpty == true
          ? (json['profile_id'] as String).trim()
          : null,
      createdAt: parseDateTime(json['created_at']),
      deletedAt: parseDateTime(json['deleted_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (clientType != null) 'client_type': clientType,
      if (profileId != null) 'profile_id': profileId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
    };
  }

  /// Pro konzistenci s fromJson (některé zdroje posílají Map místo JSON).
  factory ClientModel.fromMap(Map<String, dynamic> map) => ClientModel.fromJson(map);

  ClientModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? email,
    String? phone,
    String? clientType,
    String? profileId,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    return ClientModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      clientType: clientType ?? this.clientType,
      profileId: profileId ?? this.profileId,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
