/// Model záznamu tabulky [client_addresses] – adresa přiřazená klientovi.
///
/// Slouží pro Adresář klienta (Varianta A) při řešení transferů k externím agenturám.
/// Každý klient typu agency může mít více adres – např. "Apartmán u moře", "Kancelář v centru".
/// Umožňuje řidičům znát přesné lokace pro vyzvednutí/odvoz při transferech.
class ClientAddressModel {
  const ClientAddressModel({
    required this.id,
    required this.tenantId,
    required this.clientId,
    required this.label,
    required this.address,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String tenantId;
  /// FK na clients.id – klient, ke kterému adresa patří.
  final String clientId;
  /// Lidsky čitelný název – např. "Apartmán u moře", "Kancelář v centru".
  final String label;
  /// Plná adresa pro řidiče – ulice, město, GPS, instrukce.
  final String address;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  factory ClientAddressModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc();
      return null;
    }

    return ClientAddressModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      label: (json['label'] as String?)?.trim() ?? '',
      address: (json['address'] as String?)?.trim() ?? '',
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
      deletedAt: parseDateTime(json['deleted_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'client_id': clientId,
      'label': label,
      'address': address,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
    };
  }

  /// Pro konzistenci s fromJson (některé zdroje posílají Map místo JSON).
  factory ClientAddressModel.fromMap(Map<String, dynamic> map) =>
      ClientAddressModel.fromJson(map);
}
