import 'package:falconest/core/utils/geo_json_point.dart';

/// Sentinel pro [ClientModel.copyWith] u souřadnic – odliší „nepřepisovat“ od „vynulovat v DB“.
const Object _kClientModelGeoCopyUnset = Object();

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
    this.languageCode,
    this.profileId,
    this.agencyId,
    this.createdAt,
    this.deletedAt,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? email;
  final String? phone;
  /// Typ klienta: owner, external, agency.
  final String? clientType;
  /// Preferovaný jazyk komunikace klienta (ISO-2), např. `cs`, `en`.
  final String? languageCode;
  /// Propojení s přihlašovacím profilem (profiles.id) – pro Klientský portál majitelů.
  /// NULL = klient nemá přístup do systému, pouze záznam v CRM.
  final String? profileId;
  /// Agentura, která nám externího klienta doporučila. Pouze pro client_type = external.
  /// FK na clients.id – self-reference. NULL = klient nebyl doporučen agenturou.
  final String? agencyId;
  final DateTime? createdAt;
  final DateTime? deletedAt;
  /// Volitelná geolokace z `geo_location` (PostGIS / GeoJSON).
  final double? latitude;
  final double? longitude;

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc();
      return null;
    }

    final geoPoint = GeoJsonPoint.parseFromPostgrest(json['geo_location']);
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
      languageCode: (json['language_code'] as String?)?.trim().isNotEmpty == true
          ? (json['language_code'] as String).trim().toLowerCase()
          : null,
      profileId: (json['profile_id'] as String?)?.trim().isNotEmpty == true
          ? (json['profile_id'] as String).trim()
          : null,
      agencyId: (json['agency_id'] as String?)?.trim().isNotEmpty == true
          ? (json['agency_id'] as String).trim()
          : null,
      createdAt: parseDateTime(json['created_at']),
      deletedAt: parseDateTime(json['deleted_at']),
      latitude: geoPoint?.latitude,
      longitude: geoPoint?.longitude,
    );
  }

  Map<String, dynamic> toMap() {
    final geo = GeoJsonPoint.toPostgrestJson(latitude, longitude);
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (clientType != null) 'client_type': clientType,
      if (languageCode != null) 'language_code': languageCode,
      if (profileId != null) 'profile_id': profileId,
      if (agencyId != null) 'agency_id': agencyId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
      if (geo != null) 'geo_location': geo,
    };
  }

  /// Pro konzistenci s fromJson (některé zdroje posílají Map místo JSON).
  factory ClientModel.fromMap(Map<String, dynamic> map) => ClientModel.fromJson(map);

  /// Alias pro konzistentní pojmenování serializace napříč modely.
  Map<String, dynamic> toJson() => toMap();

  ClientModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? email,
    String? phone,
    String? clientType,
    String? languageCode,
    String? profileId,
    String? agencyId,
    DateTime? createdAt,
    DateTime? deletedAt,
    Object? latitude = _kClientModelGeoCopyUnset,
    Object? longitude = _kClientModelGeoCopyUnset,
  }) {
    return ClientModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      clientType: clientType ?? this.clientType,
      languageCode: languageCode ?? this.languageCode,
      profileId: profileId ?? this.profileId,
      agencyId: agencyId ?? this.agencyId,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      latitude: identical(latitude, _kClientModelGeoCopyUnset)
          ? this.latitude
          : latitude as double?,
      longitude: identical(longitude, _kClientModelGeoCopyUnset)
          ? this.longitude
          : longitude as double?,
    );
  }
}
