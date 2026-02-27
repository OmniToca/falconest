/// Model zařízení uživatele z tabulky [user_devices].
///
/// Reprezentuje FCM token jednoho zařízení (telefon, tablet, web).
/// [fcmToken] je unikátní identifikátor z Firebase SDK.
/// [deviceType] určuje platformu pro targeting a cleanup (ios, android, web).
/// [lastActiveAt] se aktualizuje při každém refresh tokenu – pro čištění neaktivních.
class UserDeviceModel {
  const UserDeviceModel({
    required this.id,
    required this.tenantId,
    required this.profileId,
    required this.fcmToken,
    required this.deviceType,
    this.lastActiveAt,
  });

  final String id;
  final String tenantId;
  final String profileId;
  final String fcmToken;
  /// Typ platformy: 'ios' | 'android' | 'web'
  final String deviceType;
  /// Poslední aktivita – při refresh tokenu se aktualizuje.
  final DateTime? lastActiveAt;

  factory UserDeviceModel.fromJson(Map<String, dynamic> json) {
    DateTime? lastActiveAt;
    final raw = json['last_active_at'];
    if (raw != null) {
      if (raw is DateTime) {
        lastActiveAt = raw.toUtc();
      } else if (raw is String) {
        lastActiveAt = DateTime.tryParse(raw)?.toUtc();
      }
    }

    return UserDeviceModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      fcmToken: json['fcm_token'] as String? ?? '',
      deviceType: (json['device_type'] as String?)?.trim() ?? 'web',
      lastActiveAt: lastActiveAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'profile_id': profileId,
      'fcm_token': fcmToken,
      'device_type': deviceType,
      if (lastActiveAt != null) 'last_active_at': lastActiveAt!.toIso8601String(),
    };
  }
}

