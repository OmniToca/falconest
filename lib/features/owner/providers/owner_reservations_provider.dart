import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';

/// Model jedné rezervace z tabulky reservations.
///
/// Slouží pro zobrazení v kalendáři a v UI majitele.
/// Data se načítají přes RLS – majitel vidí jen rezervace u svých bytů.
class OwnerReservation {
  const OwnerReservation({
    required this.id,
    required this.apartmentId,
    required this.startDate,
    required this.endDate,
    this.specialRequests,
  });

  final String id;
  final String apartmentId;
  final DateTime startDate;
  final DateTime endDate;
  final String? specialRequests;

  /// Vrací true, pokud [day] spadá do intervalu [startDate, endDate] (včetně).
  bool containsDay(DateTime day) {
    final normDay = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !normDay.isBefore(start) && !normDay.isAfter(end);
  }
}

/// Provider načítající rezervace majitele ze Supabase.
///
/// Dotaz na tabulku reservations – sloupce id, apartment_id, start_date,
/// end_date, special_requests. RLS na backendu zajistí, že majitel vidí jen
/// rezervace u bytů z apartment_owners.
final ownerReservationsProvider =
    FutureProvider<List<OwnerReservation>>((ref) async {
  final response = await SupabaseService.client
      .from('reservations')
      .select('id, apartment_id, start_date, end_date, special_requests')
      .isFilter('deleted_at', null);

  return (response as List).map(_parseReservation).toList();
});

/// Parsuje jeden řádek z odpovědi Supabase do [OwnerReservation].
OwnerReservation _parseReservation(dynamic raw) {
  final map = raw as Map<String, dynamic>;
  final id = map['id'] as String? ?? '';
  final apartmentId = map['apartment_id'] as String? ?? '';
  final startStr = map['start_date'] as String?;
  final endStr = map['end_date'] as String?;
  final specialRequests = map['special_requests'] as String?;

  final startDate = _parseDate(startStr) ?? DateTime.now();
  final endDate = _parseDate(endStr) ?? DateTime.now();

  return OwnerReservation(
    id: id,
    apartmentId: apartmentId,
    startDate: startDate,
    endDate: endDate,
    specialRequests: specialRequests,
  );
}

/// Parsuje ISO datum (YYYY-MM-DD) na DateTime.
DateTime? _parseDate(String? s) {
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s);
}
