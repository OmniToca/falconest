/// Session check-inu u rezervace ([guest_checkins]) – token, stav SES, SLA.
class GuestCheckin {
  const GuestCheckin({
    required this.id,
    required this.tenantId,
    required this.reservationId,
    required this.publicToken,
    this.status = 'draft',
    this.signedAt,
    this.partePdfUrl,
    this.lastError,
    this.slaAlertedAt,
  });

  final String id;
  final String tenantId;
  final String reservationId;
  final String publicToken;
  final String status;
  final DateTime? signedAt;
  final String? partePdfUrl;
  final String? lastError;
  final DateTime? slaAlertedAt;

  factory GuestCheckin.fromJson(Map<String, dynamic> json) {
    return GuestCheckin(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      reservationId: json['reservation_id'] as String? ?? '',
      publicToken: json['public_token'] as String? ?? '',
      status: (json['status'] as String?)?.trim() ?? 'draft',
      signedAt: _parse(json['signed_at']),
      partePdfUrl: json['parte_pdf_url'] as String?,
      lastError: json['last_error'] as String?,
      slaAlertedAt: _parse(json['sla_alerted_at']),
    );
  }

  static DateTime? _parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }
}

/// Řádek dashboardu: rezervace + byt + semafor SES.
class LegalComplianceRow {
  const LegalComplianceRow({
    required this.reservationId,
    required this.apartmentId,
    this.apartmentName,
    this.guestName,
    this.startDate,
    this.endDate,
    this.status = 'draft',
    this.lastError,
    this.guestCount = 0,
    this.unsignedAdults = 0,
  });

  final String reservationId;
  final String apartmentId;
  final String? apartmentName;
  final String? guestName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final String? lastError;
  final int guestCount;
  final int unsignedAdults;

  factory LegalComplianceRow.fromJson(Map<String, dynamic> json) {
    return LegalComplianceRow(
      reservationId: json['reservation_id'] as String? ?? json['id'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      apartmentName: json['apartment_name'] as String?,
      guestName: json['guest_name'] as String?,
      startDate: GuestCheckin._parse(json['start_date']),
      endDate: GuestCheckin._parse(json['end_date']),
      status: (json['status'] as String?)?.trim() ?? 'draft',
      lastError: json['last_error'] as String?,
      guestCount: _int(json['guest_count']),
      unsignedAdults: _int(json['unsigned_adults']),
    );
  }

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
