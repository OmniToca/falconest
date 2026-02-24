import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';

/// Model jedné rezervace z tabulky reservations.
///
/// Slouží pro zobrazení v Kanban boardu a UI majitele.
/// Data se načítají přes RLS – majitel vidí jen rezervace u svých bytů.
class OwnerReservation {
  const OwnerReservation({
    required this.id,
    required this.apartmentId,
    required this.startDate,
    required this.endDate,
    this.specialRequests,
    this.status = 'new',
    this.guestName,
    this.guestPhone,
    this.apartmentName,
    this.guestAdults = 0,
    this.guestChildren = 0,
    this.arrivalTime,
    this.departureTime,
  });

  final String id;
  final String apartmentId;
  final DateTime startDate;
  final DateTime endDate;
  final String? specialRequests;
  /// Životní cyklus: new, confirmed, checked_in, checked_out, cancelled.
  final String status;
  final String? guestName;
  final String? guestPhone;
  final String? apartmentName;
  final int guestAdults;
  final int guestChildren;
  final DateTime? arrivalTime;
  final DateTime? departureTime;

  /// Vrací true, pokud [day] spadá do intervalu [startDate, endDate] (včetně).
  bool containsDay(DateTime day) {
    final normDay = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !normDay.isBefore(start) && !normDay.isAfter(end);
  }

  int get totalGuests => guestAdults + guestChildren;
}

/// Provider načítající rezervace majitele ze Supabase.
///
/// Dotaz na tabulku reservations včetně joinu apartments pro Kanban board.
/// RLS na backendu zajistí, že majitel vidí jen rezervace u bytů z apartment_owners.
final ownerReservationsProvider =
    FutureProvider<List<OwnerReservation>>((ref) async {
  final response = await SupabaseService.client
      .from('reservations')
      .select(
        'id, apartment_id, start_date, end_date, special_requests, status, '
        'guest_name, guest_phone, guest_adults, guest_children, arrival_time, departure_time, '
        'apartments(name)',
      )
      .isFilter('deleted_at', null)
      .order('start_date', ascending: true);

  final list = response as List;
  final reservations = list.map(_parseReservation).toList();

  /// Fallback: pokud join nevrátil jméno bytu, načteme z ownerApartmentsProvider.
  final apartments = await ref.read(ownerApartmentsProvider.future);
  final nameById = {for (final a in apartments) a.id: a.name};

  return reservations.map((r) {
    if ((r.apartmentName == null || r.apartmentName!.isEmpty) && nameById.containsKey(r.apartmentId)) {
      return OwnerReservation(
        id: r.id,
        apartmentId: r.apartmentId,
        startDate: r.startDate,
        endDate: r.endDate,
        specialRequests: r.specialRequests,
        status: r.status,
        guestName: r.guestName,
        guestPhone: r.guestPhone,
        apartmentName: nameById[r.apartmentId],
        guestAdults: r.guestAdults,
        guestChildren: r.guestChildren,
        arrivalTime: r.arrivalTime,
        departureTime: r.departureTime,
      );
    }
    return r;
  }).toList();
});

/// Parsuje jeden řádek z odpovědi Supabase do [OwnerReservation].
OwnerReservation _parseReservation(dynamic raw) {
  final map = raw as Map<String, dynamic>;
  final id = map['id'] as String? ?? '';
  final apartmentId = map['apartment_id'] as String? ?? '';
  final startStr = map['start_date'] as String?;
  final endStr = map['end_date'] as String?;
  final specialRequests = map['special_requests'] as String?;
  final statusRaw = (map['status'] as String?)?.trim();
  const validStatuses = ['new', 'confirmed', 'checked_in', 'checked_out', 'cancelled'];
  final status = (statusRaw != null && validStatuses.contains(statusRaw))
      ? statusRaw
      : 'new';
  final guestName = (map['guest_name'] as String?)?.trim();
  final guestPhone = (map['guest_phone'] as String?)?.trim();
  final guestAdults = _parseInt(map['guest_adults'], 0);
  final guestChildren = _parseInt(map['guest_children'], 0);
  final arrivalTime = _parseOptionalDateTime(map['arrival_time']);
  final departureTime = _parseOptionalDateTime(map['departure_time']);

  String? apartmentName;
  final apt = map['apartments'];
  if (apt is Map && apt['name'] != null) {
    apartmentName = (apt['name'] as String?)?.trim();
  }

  final startDate = _parseDate(startStr) ?? DateTime.now();
  final endDate = _parseDate(endStr) ?? DateTime.now();

  return OwnerReservation(
    id: id,
    apartmentId: apartmentId,
    startDate: startDate,
    endDate: endDate,
    specialRequests: specialRequests,
    status: status,
    guestName: guestName?.isNotEmpty == true ? guestName : null,
    guestPhone: guestPhone?.isNotEmpty == true ? guestPhone : null,
    apartmentName: apartmentName?.isNotEmpty == true ? apartmentName : null,
    guestAdults: guestAdults,
    guestChildren: guestChildren,
    arrivalTime: arrivalTime,
    departureTime: departureTime,
  );
}

int _parseInt(dynamic v, int fallback) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

DateTime? _parseOptionalDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

/// Parsuje ISO datum (YYYY-MM-DD) na DateTime.
DateTime? _parseDate(String? s) {
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s);
}
