import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Model bytu z Supabase – odpovídá sloupcům tabulky apartments.
///
/// Rozšířený o životní cyklus: status, check-in/out časy, doba úklidu,
/// poznámky majitele. Multi-tenant izolace přes [tenantId].
class ApartmentRow {
  const ApartmentRow({
    required this.id,
    required this.name,
    this.address,
    this.keybox,
    required this.tenantId,
    this.zoneId,
    this.status,
    this.checkInTime,
    this.checkOutTime,
    this.standardCleaningDuration,
    this.ownerNotes,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String? address;
  final String? keybox;
  final String tenantId;
  /// Oblast (zóna), do které byt patří – FK na zones.id
  final String? zoneId;
  /// Stav bytu: Uklizeno, K úklidu, Obsazeno hosty, Probíhá úklid, Rekonstrukce
  final String? status;
  /// Standardní čas příjezdu, např. 15:00
  final String? checkInTime;
  /// Standardní čas odjezdu, např. 10:00
  final String? checkOutTime;
  /// Standardní doba úklidu v minutách
  final int? standardCleaningDuration;
  /// Preference a instrukce majitele
  final String? ownerNotes;
  /// Soft delete: když není null, záznam je považován za smazaný (v UI se neukazuje).
  final DateTime? deletedAt;

  /// Bezpečné parsování z JSON/Supabase. Fallbacky pro null hodnoty zajišťují,
  /// že model vždy má platná výchozí data (status, časy, doba úklidu).
  factory ApartmentRow.fromJson(Map<String, dynamic> json) {
    final rawDuration = json['standard_cleaning_duration'];
    int? duration;
    if (rawDuration != null) {
      if (rawDuration is int) {
        duration = rawDuration;
      } else if (rawDuration is num) {
        duration = rawDuration.toInt();
      }
    }
    final addr = (json['address'] as String?)?.trim();
    final kb = (json['keybox'] as String?)?.trim();
    final notes = (json['owner_notes'] as String?)?.trim();
    final checkIn = (json['check_in_time'] as String?)?.trim();
    final checkOut = (json['check_out_time'] as String?)?.trim();
    final zoneRaw = json['zone_id'];
    final zoneId = (zoneRaw != null && zoneRaw.toString().trim().isNotEmpty) ? zoneRaw.toString().trim() : null;
    return ApartmentRow(
      id: json['id'] as String,
      name: (json['name'] as String?)?.trim() ?? '',
      address: (addr == null || addr.isEmpty) ? null : addr,
      keybox: (kb == null || kb.isEmpty) ? null : kb,
      tenantId: json['tenant_id'] as String? ?? '',
      zoneId: zoneId,
      status: _parseStatus(json['status']),
      checkInTime: (checkIn == null || checkIn.isEmpty) ? '15:00' : checkIn,
      checkOutTime: (checkOut == null || checkOut.isEmpty) ? '10:00' : checkOut,
      standardCleaningDuration: duration ?? 120,
      ownerNotes: (notes == null || notes.isEmpty) ? null : notes,
      deletedAt: _parseOptionalDateTime(json['deleted_at']),
    );
  }

  static DateTime? _parseOptionalDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static const _statusFallback = 'Uklizeno';

  static String? _parseStatus(dynamic v) {
    if (v == null) return _statusFallback;
    final s = (v is String ? v : v.toString()).trim();
    return s.isEmpty ? _statusFallback : s;
  }

  /// Mapuje model na formát pro Supabase insert/update.
  /// Vrací Map s snake_case klíči pro tabulku apartments.
  Map<String, dynamic> toMap({bool forInsert = false}) {
    final map = <String, dynamic>{
      'name': name,
      'zone_id': zoneId,
      'address': address,
      'keybox': keybox,
      'status': status ?? _statusFallback,
      'check_in_time': checkInTime ?? '15:00',
      'check_out_time': checkOutTime ?? '10:00',
      'standard_cleaning_duration': standardCleaningDuration ?? 120,
      'owner_notes': ownerNotes,
    };
    if (forInsert) {
      map['tenant_id'] = tenantId;
    }
    return map;
  }

  ApartmentRow copyWith({
    String? id,
    String? name,
    String? address,
    String? keybox,
    String? tenantId,
    String? zoneId,
    String? status,
    String? checkInTime,
    String? checkOutTime,
    int? standardCleaningDuration,
    String? ownerNotes,
    DateTime? deletedAt,
  }) =>
      ApartmentRow(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        keybox: keybox ?? this.keybox,
        tenantId: tenantId ?? this.tenantId,
        zoneId: zoneId ?? this.zoneId,
        status: status ?? this.status,
        checkInTime: checkInTime ?? this.checkInTime,
        checkOutTime: checkOutTime ?? this.checkOutTime,
        standardCleaningDuration: standardCleaningDuration ?? this.standardCleaningDuration,
        ownerNotes: ownerNotes ?? this.ownerNotes,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}

/// Provider načítající seznam bytů z Supabase (tabulka apartments).
///
/// Explicitní filtr .eq('tenant_id', tenantIdForData) zamezí data leakage – aplikace
/// vždy filtruje (běžný uživatel = jeho tenant, Super Admin = vybraná agentura).
/// Pokud je tenantId null (Super Admin bez výběru), dotaz se neprovede – vrací [] (ne chybu).
final apartmentsProvider = FutureProvider<List<ApartmentRow>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final response = await SupabaseService.client
      .from('apartments')
      .select(
        'id, name, address, keybox, tenant_id, zone_id, status, '
        'check_in_time, check_out_time, standard_cleaning_duration, owner_notes',
      )
      .eq('tenant_id', tenantId)
      .isFilter('deleted_at', null)
      .order('name');

  return (response as List)
      .map((e) => ApartmentRow.fromJson(e as Map<String, dynamic>))
      .toList();
});
