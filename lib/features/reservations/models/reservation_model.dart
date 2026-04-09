/// Unifikovaný model řádku z tabulky `reservations` (Supabase).
///
/// PROČ: Sdílený DTO pro případné sdílené čtení rezervací napříč moduly (admin / owner).
/// Legacy příznaky `is_owner_block` / `agency_collects_payment` byly z produktu odstraněny –
/// model je drží v souladu s aktuálním schématem DB (viz `docs/ai_context/database_schema.md`).
class ReservationModel {
  const ReservationModel({
    required this.id,
    required this.apartmentId,
    required this.tenantId,
    required this.startDate,
    required this.endDate,
    this.status,
    this.guestName,
  });

  final String id;
  final String apartmentId;
  final String tenantId;
  final DateTime startDate;
  final DateTime endDate;
  final String? status;
  final String? guestName;

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return ReservationModel(
      id: (json['id'] as String?)?.trim() ?? '',
      apartmentId: (json['apartment_id'] as String?)?.trim() ?? '',
      tenantId: (json['tenant_id'] as String?)?.trim() ?? '',
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      status: (json['status'] as String?)?.trim(),
      guestName: (json['guest_name'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apartment_id': apartmentId,
      'tenant_id': tenantId,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      if (status != null) 'status': status,
      if (guestName != null) 'guest_name': guestName,
    };
  }

  ReservationModel copyWith({
    String? id,
    String? apartmentId,
    String? tenantId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? guestName,
  }) {
    return ReservationModel(
      id: id ?? this.id,
      apartmentId: apartmentId ?? this.apartmentId,
      tenantId: tenantId ?? this.tenantId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      guestName: guestName ?? this.guestName,
    );
  }
}
