import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/providers/owner_planning_calendar_apartment_filter_provider.dart';

/// Konstantní text ukládaný do [reservations.guest_name] pro blokaci termínu majitelem.
///
/// PROČ: Stabilní identifikace v DB a v reportech; UI může zobrazit lokalizovaný popisek zvlášť.
const String kOwnerStayGuestNameDb = 'Vlastní pobyt majitele';

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
    this.guestEmail,
    this.apartmentName,
    this.guestAdults = 0,
    this.guestChildren = 0,
    this.arrivalTime,
    this.departureTime,
    this.metadata,
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
  final String? guestEmail;
  final String? apartmentName;
  final int guestAdults;
  final int guestChildren;
  final DateTime? arrivalTime;
  final DateTime? departureTime;

  /// Rozšíření z DB (např. is_owner_stay pro blokace).
  final Map<String, dynamic>? metadata;

  bool get isOwnerStay => metadata?['is_owner_stay'] == true;

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
/// SECURITY: Striktní filtr na apartment_id – načteme jen ID vlastněných bytů
/// z apartment_owners (ownerApartmentsProvider) a dotaz omezíme na ně.
/// Obrana v hloubce k RLS (reservations_property_owner_select).
final ownerReservationsProvider = FutureProvider<List<OwnerReservation>>((
  ref,
) async {
  final apartments = await ref.read(ownerApartmentsProvider.future);
  final ownedApartmentIds = apartments
      .map((a) => a.id)
      .where((id) => id.isNotEmpty)
      .toList();

  if (ownedApartmentIds.isEmpty) return [];

  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final response = await SupabaseService.safeFrom('reservations', tenantId)
      .select(
        'id, apartment_id, start_date, end_date, special_requests, status, '
        'guest_name, guest_phone, guest_email, guest_adults, guest_children, arrival_time, departure_time, '
        'metadata, apartments(name)',
      )
      .inFilter('apartment_id', ownedApartmentIds)
      .isFilter('deleted_at', null)
      .order('start_date', ascending: true);

  final list = response as List;
  final reservations = list.map(_parseReservation).toList();

  /// Fallback: pokud join nevrátil jméno bytu, doplníme z načtených apartmánů.
  return _mergeApartmentNames(reservations, apartments);
});

/// ISO datum `YYYY-MM-DD` pro filtry Supabase nad sloupci typu `date`.
String _reservationDateToSql(DateTime localDate) {
  final y = localDate.year.toString().padLeft(4, '0');
  final m = localDate.month.toString().padLeft(2, '0');
  final d = localDate.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Rezervace majitele pro plánovací kalendář – pouze překryv s kalendářním měsícem [weekStart].
///
/// PROČ: [ownerReservationsProvider] tahá celou historii; kalendář potřebuje jen měsíc (all-day + týdny).
/// Dotaz: `end_date >= první_den_měsíce` a `start_date <= poslední_den_měsíce` (stejná logika překryvu jako v admin repozitáři).
final ownerReservationsForPlanningCalendarProvider = FutureProvider.autoDispose
    .family<List<OwnerReservation>, DateTime>((ref, weekStart) async {
      ref.watch(ownerPlanningCalendarApartmentFilterProvider);

      final apartments = await ref.read(ownerApartmentsProvider.future);
      final ownedApartmentIds = apartments
          .map((a) => a.id)
          .where((id) => id.isNotEmpty)
          .toList();

      if (ownedApartmentIds.isEmpty) return [];

      final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
      if (tenantId == null || tenantId.isEmpty) return [];

      final filterApartmentId = ref.watch(ownerPlanningCalendarApartmentFilterProvider);
      final apartmentIdsForQuery =
          (filterApartmentId != null &&
                  filterApartmentId.isNotEmpty &&
                  ownedApartmentIds.contains(filterApartmentId))
              ? <String>[filterApartmentId]
              : ownedApartmentIds;

      final anchor = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final monthStart = DateTime(anchor.year, anchor.month, 1);
      final monthEnd = DateTime(anchor.year, anchor.month + 1, 0);
      final rangeStart = _reservationDateToSql(monthStart);
      final rangeEnd = _reservationDateToSql(monthEnd);

      try {
        final response = await SupabaseService.safeFrom('reservations', tenantId)
            .select(
              'id, apartment_id, start_date, end_date, special_requests, status, '
              'guest_name, guest_phone, guest_email, guest_adults, guest_children, arrival_time, departure_time, '
              'metadata, apartments(name)',
            )
            .inFilter('apartment_id', apartmentIdsForQuery)
            .isFilter('deleted_at', null)
            .gte('end_date', rangeStart)
            .lte('start_date', rangeEnd)
            .order('start_date', ascending: true);

        final list = response as List;
        final reservations = list.map(_parseReservation).toList();
        return _mergeApartmentNames(reservations, apartments);
      } catch (e, st) {
        AppLogger.error('ownerReservationsForPlanningCalendarProvider: dotaz rezervací selhal', e, st);
        return [];
      }
    });

/// Doplnění názvu bytu z cache apartmánů (stejně jako u plného provideru).
List<OwnerReservation> _mergeApartmentNames(
  List<OwnerReservation> reservations,
  List<OwnerApartmentWithStatus> apartments,
) {
  final nameById = {for (final a in apartments) a.id: a.name};

  return reservations.map((r) {
    if ((r.apartmentName == null || r.apartmentName!.isEmpty) &&
        nameById.containsKey(r.apartmentId)) {
      return OwnerReservation(
        id: r.id,
        apartmentId: r.apartmentId,
        startDate: r.startDate,
        endDate: r.endDate,
        specialRequests: r.specialRequests,
        status: r.status,
        guestName: r.guestName,
        guestPhone: r.guestPhone,
        guestEmail: r.guestEmail,
        apartmentName: nameById[r.apartmentId],
        guestAdults: r.guestAdults,
        guestChildren: r.guestChildren,
        arrivalTime: r.arrivalTime,
        departureTime: r.departureTime,
        metadata: r.metadata,
      );
    }
    return r;
  }).toList();
}

/// Parsuje jeden řádek z odpovědi Supabase do [OwnerReservation].
OwnerReservation _parseReservation(dynamic raw) {
  final map = raw as Map<String, dynamic>;
  final id = map['id'] as String? ?? '';
  final apartmentId = map['apartment_id'] as String? ?? '';
  final startStr = map['start_date'] as String?;
  final endStr = map['end_date'] as String?;
  final specialRequests = map['special_requests'] as String?;
  final statusRaw = (map['status'] as String?)?.trim();
  const validStatuses = [
    'new',
    'confirmed',
    'checked_in',
    'checked_out',
    'cancelled',
  ];
  final status = (statusRaw != null && validStatuses.contains(statusRaw))
      ? statusRaw
      : 'new';
  final guestName = (map['guest_name'] as String?)?.trim();
  final guestPhone = (map['guest_phone'] as String?)?.trim();
  final guestEmail = (map['guest_email'] as String?)?.trim();
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

  Map<String, dynamic>? meta;
  final rawMeta = map['metadata'];
  if (rawMeta is Map) {
    meta = Map<String, dynamic>.from(rawMeta);
  }

  return OwnerReservation(
    id: id,
    apartmentId: apartmentId,
    startDate: startDate,
    endDate: endDate,
    specialRequests: specialRequests,
    status: status,
    guestName: guestName?.isNotEmpty == true ? guestName : null,
    guestPhone: guestPhone?.isNotEmpty == true ? guestPhone : null,
    guestEmail: guestEmail?.isNotEmpty == true ? guestEmail : null,
    apartmentName: apartmentName?.isNotEmpty == true ? apartmentName : null,
    guestAdults: guestAdults,
    guestChildren: guestChildren,
    arrivalTime: arrivalTime,
    departureTime: departureTime,
    metadata: meta,
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
