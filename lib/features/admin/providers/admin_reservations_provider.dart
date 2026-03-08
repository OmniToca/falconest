import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/admin_reservations_repository.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/apartment_owners_provider.dart';
import 'package:falconest/features/admin/providers/clients_provider.dart';

/// Životní cyklus rezervace – hodnoty sloupce status v DB (výchozí 'new').
const List<String> reservationStatusValues = ['new', 'confirmed', 'checked_in', 'checked_out', 'cancelled'];

/// Povolené hodnoty zdroje rezervace (reservation_source) – pro dropdown a CHECK v DB.
const List<String> reservationSourceValues = ['Booking', 'Airbnb', 'Direct', 'Other'];

/// Vrací i18n klíč pro štítek stavu rezervace (admin.reservation_status_*).
String reservationStatusLabelKey(String status) {
  if (reservationStatusValues.contains(status)) return 'admin.reservation_status_$status';
  return 'admin.reservation_status_new';
}

/// Model rezervace z tabulky reservations pro Admin modul.
///
/// Obsahuje id, apartment_id, guest_name, guest_phone, reservation_source,
/// check_in, check_out, needs_transfer, status, guest_adults, guest_children,
/// arrival_time, departure_time (Override Tier 3 – rozšíření pro rezervace a Task Automator).
/// [apartmentName] se naplní z joinu s tabulkou apartments.
class ReservationRow {
  const ReservationRow({
    required this.id,
    required this.apartmentId,
    this.referenceNumber,
    this.guestName,
    this.guestPhone,
    this.reservationSource,
    this.checkIn,
    this.checkOut,
    this.needsTransfer,
    this.status = 'new',
    this.apartmentName,
    this.deletedAt,
    this.guestAdults = 0,
    this.guestChildren = 0,
    this.arrivalTime,
    this.departureTime,
    this.internalNote,
  });

  final String id;
  final String apartmentId;
  /// Referenční číslo (např. RES-A8B3K9). Lidsky čitelný identifikátor pro podporu.
  final String? referenceNumber;
  /// Jméno hosta – fallback prázdný řetězec
  final String? guestName;
  /// Telefon hosta (pro transfery a předání)
  final String? guestPhone;
  /// Zdroj rezervace: Booking, Airbnb, Direct, Other
  final String? reservationSource;
  /// Termín příjezdu – text (např. '25.08.2026') nebo ISO
  final String? checkIn;
  /// Termín odjezdu
  final String? checkOut;
  /// Zda host požaduje transfer na letiště (legacy; služby se řeší přes reservation_services)
  final bool? needsTransfer;
  /// Životní cyklus: new, confirmed, checked_in, checked_out, cancelled (výchozí 'new')
  final String status;
  /// Název apartmánu z tabulky apartments (načteno joinem)
  final String? apartmentName;
  /// Soft delete: když není null, záznam je považován za smazaný (v UI se neukazuje).
  final DateTime? deletedAt;
  /// Počet dospělých hostů (sloupec guest_adults).
  final int guestAdults;
  /// Počet dětí (sloupec guest_children).
  final int guestChildren;
  /// Předpokládaný čas příjezdu (sloupec arrival_time, timestamptz) – zobrazuje se jen čas.
  final DateTime? arrivalTime;
  /// Předpokládaný čas odjezdu (sloupec departure_time, timestamptz) – pro úklid a transfer na letiště.
  final DateTime? departureTime;
  /// Interní poznámka manažera – nesynchronizuje se do mobilní aplikace personálu.
  final String? internalNote;

  /// Bezpečné parsování z JSON. DB používá start_date/end_date (povinné).
  /// check_in/check_out jsou volitelné rozšíření; preferujeme start_date/end_date.
  factory ReservationRow.fromJson(Map<String, dynamic> json) {
    final raw = json;
    final id = raw['id'] as String? ?? '';
    final apartmentId = raw['apartment_id'] as String? ?? '';
    final guestName = (raw['guest_name'] as String?)?.trim();
    var checkIn = (raw['start_date'] != null)
        ? _formatIsoToDisplay(raw['start_date'].toString())
        : (raw['check_in'] as String?)?.trim();
    var checkOut = (raw['end_date'] != null)
        ? _formatIsoToDisplay(raw['end_date'].toString())
        : (raw['check_out'] as String?)?.trim();
    final needsTransfer = _parseBool(raw['needs_transfer']);
    final status = (raw['status'] as String?)?.trim();
    final statusVal = status != null && reservationStatusValues.contains(status)
        ? status
        : 'new';

    /// apartments je vnořený objekt z Postgrest joinu (apartments(name))
    String? apartmentName;
    final apt = raw['apartments'];
    if (apt is Map && apt['name'] != null) {
      apartmentName = apt['name'] as String?;
    }

    final guestAdults = _parseInt(raw['guest_adults'], 0);
    final guestChildren = _parseInt(raw['guest_children'], 0);
    final arrivalTime = _parseOptionalDateTime(raw['arrival_time']);
    final guestPhone = (raw['guest_phone'] as String?)?.trim();
    final reservationSourceRaw = (raw['reservation_source'] as String?)?.trim();
    final reservationSource = reservationSourceRaw != null &&
            reservationSourceValues.contains(reservationSourceRaw)
        ? reservationSourceRaw
        : null;
    final departureTime = _parseOptionalDateTime(raw['departure_time']);
    final internalNote = (raw['internal_note'] as String?)?.trim();
    /// Referenční číslo (reference_number) – pro zobrazení v UI (#RES-xxx).
    final refNum = (raw['reference_number'] as String?)?.trim();

    return ReservationRow(
      id: id,
      apartmentId: apartmentId,
      referenceNumber: refNum != null && refNum.isNotEmpty ? refNum : null,
      guestName: guestName?.isNotEmpty == true ? guestName : null,
      guestPhone: guestPhone?.isNotEmpty == true ? guestPhone : null,
      reservationSource: reservationSource,
      checkIn: checkIn?.isNotEmpty == true ? checkIn : null,
      checkOut: checkOut?.isNotEmpty == true ? checkOut : null,
      needsTransfer: needsTransfer,
      status: statusVal,
      apartmentName: apartmentName?.trim().isNotEmpty == true ? apartmentName : null,
      deletedAt: _parseOptionalDateTime(raw['deleted_at']),
      guestAdults: guestAdults,
      guestChildren: guestChildren,
      arrivalTime: arrivalTime,
      departureTime: departureTime,
      internalNote: internalNote?.isNotEmpty == true ? internalNote : null,
    );
  }

  static int _parseInt(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static DateTime? _parseOptionalDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    return false;
  }

  /// Převádí ISO datum (yyyy-MM-dd) z DB na český formát DD.MM.YYYY pro zobrazení.
  static String _formatIsoToDisplay(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }

  /// Mapuje model na formát pro Supabase insert/update.
  /// DB vyžaduje start_date a end_date (ISO Date yyyy-MM-dd).
  Map<String, dynamic> toMap({bool forInsert = false}) {
    final map = <String, dynamic>{
      'apartment_id': apartmentId,
      'reference_number': referenceNumber?.trim().isEmpty == true ? null : referenceNumber,
      'guest_name': guestName?.trim().isEmpty == true ? null : guestName?.trim(),
      'guest_phone': guestPhone?.trim().isEmpty == true ? null : guestPhone?.trim(),
      'reservation_source': reservationSource ?? 'Other',
      'needs_transfer': needsTransfer ?? false,
      'status': reservationStatusValues.contains(status) ? status : 'new',
      'guest_adults': guestAdults,
      'guest_children': guestChildren,
    };
    if (checkIn != null && checkIn!.trim().isNotEmpty) {
      map['start_date'] = _toIsoDate(checkIn!);
    }
    if (checkOut != null && checkOut!.trim().isNotEmpty) {
      map['end_date'] = _toIsoDate(checkOut!);
    }
    if (arrivalTime != null) {
      map['arrival_time'] = arrivalTime!.toUtc().toIso8601String();
    } else {
      map['arrival_time'] = null;
    }
    if (departureTime != null) {
      map['departure_time'] = departureTime!.toUtc().toIso8601String();
    } else {
      map['departure_time'] = null;
    }
    map['internal_note'] = internalNote?.trim().isEmpty == true ? null : internalNote?.trim();
    return map;
  }

  static String? _toIsoDate(String displayValue) {
    final trimmed = displayValue.trim();
    if (trimmed.isEmpty) return null;
    try {
      if (trimmed.contains(' ')) {
        final parts = trimmed.split(' ');
        final dParts = parts[0].split('.');
        if (dParts.length >= 3) {
          return '${int.parse(dParts[2])}-${dParts[1].padLeft(2, '0')}-${dParts[0].padLeft(2, '0')}';
        }
      } else {
        final dParts = trimmed.split('.');
        if (dParts.length >= 3) {
          return '${int.parse(dParts[2])}-${dParts[1].padLeft(2, '0')}-${dParts[0].padLeft(2, '0')}';
        }
      }
    } catch (_) {}
    return null;
  }
}

/// Bezpečný výpočet trendu v procentech: (today - yesterday) / yesterday * 100.
/// Pokud yesterday == 0 a today > 0, vrací 100.0. Pokud oba 0, vrací 0.0.
double _calculateTrend(int today, int yesterday) {
  if (yesterday == 0) {
    if (today > 0) return 100.0;
    return 0.0;
  }
  return ((today - yesterday) / yesterday) * 100;
}

/// Parsuje datum příjezdu z textu (DD.MM.YYYY nebo DD.MM.YYYY HH:mm).
DateTime? _parseReservationCheckIn(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parts = s.trim().split(' ');
  final dParts = parts[0].split('.');
  if (dParts.length < 3) return null;
  try {
    int h = 15, min = 0;
    if (parts.length >= 2) {
      final tParts = parts[1].split(':');
      if (tParts.length >= 2) {
        h = int.parse(tParts[0]);
        min = int.parse(tParts[1]);
      }
    }
    return DateTime(
      int.parse(dParts[2]),
      int.parse(dParts[1]),
      int.parse(dParts[0]),
      h,
      min,
    );
  } catch (_) {
    return null;
  }
}

/// Parsuje datum odjezdu z textu (DD.MM.YYYY nebo DD.MM.YYYY HH:mm).
DateTime? _parseReservationCheckOut(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final parts = s.trim().split(' ');
  final dParts = parts[0].split('.');
  if (dParts.length < 3) return null;
  try {
    int h = 10, min = 0;
    if (parts.length >= 2) {
      final tParts = parts[1].split(':');
      if (tParts.length >= 2) {
        h = int.parse(tParts[0]);
        min = int.parse(tParts[1]);
      }
    }
    return DateTime(
      int.parse(dParts[2]),
      int.parse(dParts[1]),
      int.parse(dParts[0]),
      h,
      min,
    );
  } catch (_) {
    return null;
  }
}

/// Zjišťuje, zda datum z parsované rezervace spadá do daného dne.
bool _isReservationOnDay(DateTime? dt, DateTime day) {
  if (dt == null) return false;
  return dt.year == day.year && dt.month == day.month && dt.day == day.day;
}

/// Provider načítající rezervace pro Admin – Realtime stream.
///
/// PROČ: Dispečer vidí nové rezervace a změny okamžitě bez F5 (Supabase WebSockets).
/// Rezervace nemají tenant_id; filtrujeme přes apartment_id IN (byty tohoto tenanta).
/// tenantIdForData = běžný uživatel jeho tenant, Super Admin vybraná agentura.
final adminReservationsProvider =
    StreamProvider<List<ReservationRow>>((ref) async* {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  final apartments = await ref.watch(apartmentsFullListProvider.future);
  final apartmentIds = apartments.map((a) => a.id).where((id) => id.isNotEmpty).toList();
  if (apartmentIds.isEmpty) {
    yield [];
    return;
  }

  final nameMap = {for (final a in apartments) a.id: a.name};

  await for (final rawList in AdminReservationsRepository.instance.watchReservationsRaw(apartmentIds)) {
    try {
      final rows = rawList.map((raw) {
        final enriched = Map<String, dynamic>.from(raw);
        if (enriched['apartments'] == null && nameMap[raw['apartment_id']?.toString()] != null) {
          enriched['apartments'] = {'name': nameMap[raw['apartment_id']?.toString()]};
        }
        return ReservationRow.fromJson(enriched);
      }).toList();
      yield rows;
    } on PostgrestException catch (e) {
      // ignore: avoid_print
      print('--- CHYBA STREAMU REZERVACÍ: $e');
      rethrow;
    }
  }
});

/// Provider: rezervace související s klientem (parametr clientId).
///
/// LOGIKA: Tabulka [reservations] nemá přímo client_id. Pro majitele (owner) se
/// rezervace vážou přes byty: client.profile_id → apartment_owners.owner_id →
/// apartment_id → reservations.apartment_id. Pro externí/agency klienty vracíme
/// prázdný seznam (není jak je propojit).
///
/// Načte klienta z clientsProvider, pokud je owner s profile_id, získá ID bytů
/// z apartment_owners a načte rezervace těchto bytů. Seřazeno od nejbližších
/// (start_date ASC). Soft delete: pouze deleted_at IS NULL.
final clientReservationsProvider =
    FutureProvider.autoDispose.family<List<ReservationRow>, String>((ref, clientId) async {
  if (clientId.trim().isEmpty) return [];

  final clients = await ref.watch(clientsFullListProvider.future);
  final client = clients.where((c) => c.id == clientId).firstOrNull;
  if (client == null) return [];

  final isOwner = (client.clientType?.toLowerCase() ?? '') == 'owner';
  final profileId = client.profileId?.trim();
  if (!isOwner || profileId == null || profileId.isEmpty) return [];

  final apartments = await ref.watch(apartmentsForProfileProvider(profileId).future);
  final apartmentIds = apartments.map((a) => a.id).where((id) => id.isNotEmpty).toList();
  if (apartmentIds.isEmpty) return [];

  final res = await SupabaseService.client
      .from('reservations')
      .select('id, apartment_id, reference_number, guest_name, guest_phone, reservation_source, '
          'start_date, end_date, check_in, check_out, needs_transfer, status, '
          'guest_adults, guest_children, arrival_time, departure_time, internal_note, deleted_at, '
          'apartments(name)')
      .inFilter('apartment_id', apartmentIds)
      .isFilter('deleted_at', null)
      .order('start_date', ascending: true);

  return (res as List)
      .map((r) => ReservationRow.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// Provider: rezervace pro jeden byt (pro záložku Rezervace v detailu apartmánu).
///
/// Načte rezervace s apartment_id = [apartmentId], deleted_at IS NULL,
/// řazeno start_date ASC. Invaliduj po přidání/úpravě/smazání rezervace.
final reservationsForApartmentProvider =
    FutureProvider.autoDispose.family<List<ReservationRow>, String>((ref, apartmentId) async {
  if (apartmentId.trim().isEmpty) return [];

  final res = await SupabaseService.client
      .from('reservations')
      .select('id, apartment_id, reference_number, guest_name, guest_phone, reservation_source, '
          'start_date, end_date, check_in, check_out, needs_transfer, status, '
          'guest_adults, guest_children, arrival_time, departure_time, internal_note, deleted_at, '
          'apartments(name)')
      .eq('apartment_id', apartmentId)
      .isFilter('deleted_at', null)
      .order('start_date', ascending: true);

  return (res as List)
      .map((r) => ReservationRow.fromJson(r as Map<String, dynamic>))
      .toList();
});

/// Derive provider: srovnání Dnes vs. Včera pro příjezdy a odjezdy.
/// Počítá checkInsTrend a checkOutsTrend jako procentuální změnu oproti včerejšku.
final adminReservationsTrendsProvider = Provider<({double checkInsTrend, double checkOutsTrend})>((ref) {
  final async = ref.watch(adminReservationsProvider);
  final reservations = async.valueOrNull ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  int todayCheckIns = 0, todayCheckOuts = 0, yesterdayCheckIns = 0, yesterdayCheckOuts = 0;
  for (final r in reservations) {
    final ci = _parseReservationCheckIn(r.checkIn);
    final co = _parseReservationCheckOut(r.checkOut);
    if (ci != null) {
      if (_isReservationOnDay(ci, today)) todayCheckIns++;
      if (_isReservationOnDay(ci, yesterday)) yesterdayCheckIns++;
    }
    if (co != null) {
      if (_isReservationOnDay(co, today)) todayCheckOuts++;
      if (_isReservationOnDay(co, yesterday)) yesterdayCheckOuts++;
    }
  }

  return (
    checkInsTrend: _calculateTrend(todayCheckIns, yesterdayCheckIns),
    checkOutsTrend: _calculateTrend(todayCheckOuts, yesterdayCheckOuts),
  );
});
