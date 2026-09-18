/// Osoba k pobytu (tabulka [reservation_guests]) – pole RD 933/2021.
///
/// PROČ: Rezervace má jen `guest_name`; zákon vyžaduje všechny osoby včetně dětí.
/// Podpis 14+ je v [signaturePngBase64]; mladší 14 let podepisuje dospělý (bez vlastního podpisu).
class ReservationGuest {
  const ReservationGuest({
    required this.id,
    required this.tenantId,
    required this.reservationId,
    this.firstName = '',
    this.lastName = '',
    this.secondLastName,
    this.birthDate,
    this.nationality,
    this.sex,
    this.documentType,
    this.documentNumber,
    this.documentSupport,
    this.addressLine,
    this.addressCity,
    this.addressCountry,
    this.phone,
    this.email,
    this.kinship,
    this.isMinorUnder14 = false,
    this.signedAt,
    this.signaturePngBase64,
  });

  final String id;
  final String tenantId;
  final String reservationId;
  final String firstName;
  final String lastName;
  final String? secondLastName;
  final DateTime? birthDate;
  final String? nationality;
  final String? sex;
  final String? documentType;
  final String? documentNumber;
  final String? documentSupport;
  final String? addressLine;
  final String? addressCity;
  final String? addressCountry;
  final String? phone;
  final String? email;
  final String? kinship;
  final bool isMinorUnder14;
  final DateTime? signedAt;
  final String? signaturePngBase64;

  bool get isSigned => signedAt != null && (signaturePngBase64 ?? '').isNotEmpty;

  String get displayName {
    final parts = [
      firstName.trim(),
      lastName.trim(),
      (secondLastName ?? '').trim(),
    ].where((e) => e.isNotEmpty);
    return parts.join(' ');
  }

  factory ReservationGuest.fromJson(Map<String, dynamic> json) {
    return ReservationGuest(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      reservationId: json['reservation_id'] as String? ?? '',
      firstName: (json['first_name'] as String?)?.trim() ?? '',
      lastName: (json['last_name'] as String?)?.trim() ?? '',
      secondLastName: (json['second_last_name'] as String?)?.trim(),
      birthDate: _parseDate(json['birth_date']),
      nationality: (json['nationality'] as String?)?.trim(),
      sex: (json['sex'] as String?)?.trim(),
      documentType: (json['document_type'] as String?)?.trim(),
      documentNumber: (json['document_number'] as String?)?.trim(),
      documentSupport: (json['document_support'] as String?)?.trim(),
      addressLine: (json['address_line'] as String?)?.trim(),
      addressCity: (json['address_city'] as String?)?.trim(),
      addressCountry: (json['address_country'] as String?)?.trim(),
      phone: (json['phone'] as String?)?.trim(),
      email: (json['email'] as String?)?.trim(),
      kinship: (json['kinship'] as String?)?.trim(),
      isMinorUnder14: json['is_minor_under_14'] == true,
      signedAt: _parseDt(json['signed_at']),
      signaturePngBase64: json['signature_png_base64'] as String?,
    );
  }

  Map<String, dynamic> toUpsertJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'second_last_name': secondLastName?.trim(),
      'birth_date': birthDate == null
          ? null
          : '${birthDate!.year.toString().padLeft(4, '0')}-'
              '${birthDate!.month.toString().padLeft(2, '0')}-'
              '${birthDate!.day.toString().padLeft(2, '0')}',
      'nationality': nationality?.trim(),
      'sex': sex?.trim(),
      'document_type': documentType?.trim(),
      'document_number': documentNumber?.trim(),
      'document_support': documentSupport?.trim(),
      'address_line': addressLine?.trim(),
      'address_city': addressCity?.trim(),
      'address_country': addressCountry?.trim(),
      'phone': phone?.trim(),
      'email': email?.trim(),
      'kinship': kinship?.trim(),
      'is_minor_under_14': isMinorUnder14,
    };
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  static DateTime? _parseDt(dynamic raw) => _parseDate(raw);
}
