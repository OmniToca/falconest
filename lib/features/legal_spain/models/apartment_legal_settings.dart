/// Veřejné SES kódy u bytu – bez WS hesla (to je v [ses_ws_credentials]).
class ApartmentLegalSettings {
  const ApartmentLegalSettings({
    required this.apartmentId,
    required this.tenantId,
    this.sesEstablishmentCode,
    this.sesLandlordCode,
    this.legalAuthority = 'ses',
    this.touristLicense,
    this.defaultPaymentType = 'EFECTIVO',
    this.houseRules,
    this.publicWebOrigin,
    this.wsUsername,
    this.hasWsPassword = false,
  });

  final String apartmentId;
  final String tenantId;
  final String? sesEstablishmentCode;
  final String? sesLandlordCode;
  final String legalAuthority;
  final String? touristLicense;
  final String defaultPaymentType;
  final String? houseRules;
  final String? publicWebOrigin;
  final String? wsUsername;
  final bool hasWsPassword;

  factory ApartmentLegalSettings.fromJson(Map<String, dynamic> json) {
    return ApartmentLegalSettings(
      apartmentId: json['apartment_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      sesEstablishmentCode: (json['ses_establishment_code'] as String?)?.trim(),
      sesLandlordCode: (json['ses_landlord_code'] as String?)?.trim(),
      legalAuthority: (json['legal_authority'] as String?)?.trim() ?? 'ses',
      touristLicense: (json['tourist_license'] as String?)?.trim(),
      defaultPaymentType:
          (json['default_payment_type'] as String?)?.trim() ?? 'EFECTIVO',
      houseRules: json['house_rules'] as String?,
      publicWebOrigin: (json['public_web_origin'] as String?)?.trim(),
      wsUsername: (json['ws_username'] as String?)?.trim(),
      hasWsPassword: json['has_ws_password'] == true,
    );
  }

  Map<String, dynamic> toSettingsPayload() => {
        'apartment_id': apartmentId,
        'tenant_id': tenantId,
        'ses_establishment_code': sesEstablishmentCode,
        'ses_landlord_code': sesLandlordCode,
        'legal_authority': legalAuthority,
        'tourist_license': touristLicense,
        'default_payment_type': defaultPaymentType,
        'house_rules': houseRules,
        'public_web_origin': publicWebOrigin,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}
