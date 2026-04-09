import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
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
/// [specialRequests] mapuje pole viditelné hostu / majiteli (Worker/Owner z DB čtou stejně).
/// [apartmentName] se naplní z joinu s tabulkou apartments.
class ReservationRow {
  const ReservationRow({
    required this.id,
    required this.apartmentId,
    this.referenceNumber,
    this.guestName,
    this.guestPhone,
    this.guestLanguage,
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
    this.specialRequests,
    this.lastCommunicationTemplateContext,
    this.lastCommunicationAt,
    this.lastCommunicationTemplateId,
    this.createdAt,
  });

  final String id;
  final String apartmentId;
  /// Referenční číslo (např. RES-A8B3K9). Lidsky čitelný identifikátor pro podporu.
  final String? referenceNumber;
  /// Jméno hosta – fallback prázdný řetězec
  final String? guestName;
  /// Telefon hosta (pro transfery a předání)
  final String? guestPhone;
  /// Jazyk komunikace s hostem (cs/en/es...).
  ///
  /// Nullable v DB kvůli historickým záznamům; UI a filtrování musí fallbackovat na `'en'`.
  final String? guestLanguage;
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
  /// Speciální požadavky hosta (`special_requests`) – vidí dispečer, worker i owner flow.
  final String? specialRequests;
  /// trigger_context poslední šablony (WhatsApp odkaz) – pro indikátor „zpráva připravena“.
  final String? lastCommunicationTemplateContext;
  /// Čas posledního vygenerování WhatsApp odkazu (UTC).
  final DateTime? lastCommunicationAt;
  /// ID šablony (tenant_message_templates.id) použitée pro poslední odkaz – přesná shoda v UI.
  final String? lastCommunicationTemplateId;

  /// Čas vytvoření záznamu v DB (`created_at`) – pro štítek stáří rezervace v Kanbanu.
  final DateTime? createdAt;

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
    final guestLanguageRaw = (raw['guest_language'] as String?)?.trim();
    final guestLanguageVal = guestLanguageRaw != null && guestLanguageRaw.isNotEmpty
        ? guestLanguageRaw.toLowerCase()
        : null;
    final reservationSourceRaw = (raw['reservation_source'] as String?)?.trim();
    final reservationSource = reservationSourceRaw != null &&
            reservationSourceValues.contains(reservationSourceRaw)
        ? reservationSourceRaw
        : null;
    final departureTime = _parseOptionalDateTime(raw['departure_time']);
    final internalNote = (raw['internal_note'] as String?)?.trim();
    final specialRequestsRaw = (raw['special_requests'] as String?)?.trim();
    /// Referenční číslo (reference_number) – pro zobrazení v UI (#RES-xxx).
    final refNum = (raw['reference_number'] as String?)?.trim();
    final lastCtx = (raw['last_communication_template_context'] as String?)?.trim();
    final lastAt = _parseOptionalDateTime(raw['last_communication_at']);
    final lastTemplateId = (raw['last_communication_template_id'] as String?)?.trim();
    final lastTemplateIdVal = (lastTemplateId != null && lastTemplateId.isNotEmpty) ? lastTemplateId : null;

    return ReservationRow(
      id: id,
      apartmentId: apartmentId,
      referenceNumber: refNum != null && refNum.isNotEmpty ? refNum : null,
      guestName: guestName?.isNotEmpty == true ? guestName : null,
      guestPhone: guestPhone?.isNotEmpty == true ? guestPhone : null,
      guestLanguage: guestLanguageVal,
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
      specialRequests:
          specialRequestsRaw != null && specialRequestsRaw.isNotEmpty ? specialRequestsRaw : null,
      lastCommunicationTemplateContext: lastCtx?.isNotEmpty == true ? lastCtx : null,
      lastCommunicationAt: lastAt,
      lastCommunicationTemplateId: lastTemplateIdVal,
      createdAt: _parseOptionalDateTime(raw['created_at']),
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
      'guest_language': guestLanguage?.trim().isNotEmpty == true ? guestLanguage?.trim().toLowerCase() : null,
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
    // PROČ: Stejná pole musí projít insert/update z Admin formuláře i do auditu (toMap u soft-delete).
    map['special_requests'] =
        specialRequests?.trim().isEmpty == true ? null : specialRequests?.trim();
    return map;
  }

  /// Alias pro JSON-like serializaci.
  ///
  /// PROČ: v aplikaci používáme historicky `toMap()`, ale některé komponenty
  /// očekávají `toJson()` konvenci.
  Map<String, dynamic> toJson({bool forInsert = false}) => toMap(forInsert: forInsert);

  /// Vytvoří kopii modelu s upravenými poli.
  ReservationRow copyWith({
    String? referenceNumber,
    String? guestName,
    String? guestPhone,
    String? guestLanguage,
    String? reservationSource,
    String? checkIn,
    String? checkOut,
    bool? needsTransfer,
    String? status,
    String? apartmentName,
    DateTime? deletedAt,
    int? guestAdults,
    int? guestChildren,
    DateTime? arrivalTime,
    DateTime? departureTime,
    String? internalNote,
    String? specialRequests,
    String? lastCommunicationTemplateContext,
    DateTime? lastCommunicationAt,
    String? lastCommunicationTemplateId,
    DateTime? createdAt,
  }) {
    return ReservationRow(
      id: id,
      apartmentId: apartmentId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      guestName: guestName ?? this.guestName,
      guestPhone: guestPhone ?? this.guestPhone,
      guestLanguage: guestLanguage ?? this.guestLanguage,
      reservationSource: reservationSource ?? this.reservationSource,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      needsTransfer: needsTransfer ?? this.needsTransfer,
      status: status ?? this.status,
      apartmentName: apartmentName ?? this.apartmentName,
      deletedAt: deletedAt ?? this.deletedAt,
      guestAdults: guestAdults ?? this.guestAdults,
      guestChildren: guestChildren ?? this.guestChildren,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureTime: departureTime ?? this.departureTime,
      internalNote: internalNote ?? this.internalNote,
      specialRequests: specialRequests ?? this.specialRequests,
      lastCommunicationTemplateContext: lastCommunicationTemplateContext ?? this.lastCommunicationTemplateContext,
      lastCommunicationAt: lastCommunicationAt ?? this.lastCommunicationAt,
      lastCommunicationTemplateId: lastCommunicationTemplateId ?? this.lastCommunicationTemplateId,
      createdAt: createdAt ?? this.createdAt,
    );
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
    } catch (e, st) {
      AppLogger.error('admin_reservations_provider: normalizace data do ISO řetězce selhala', e, st);
    }
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
  } catch (e, st) {
    AppLogger.error('_parseReservationCheckIn: parsování data příjezdu selhalo', e, st);
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
  } catch (e, st) {
    AppLogger.error('_parseReservationCheckOut: parsování data odjezdu selhalo', e, st);
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
/// [watchReservationsRaw] používá [safeFrom] (tenant_id); u Realtime zůstává jeden inFilter,
/// proto se byty tenantů dořežou v repozitáři. Úvodní HTTP select má inFilter bytů i safeFrom.
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

  await for (final rawList
      in AdminReservationsRepository.instance.watchReservationsRaw(apartmentIds, tenantId)) {
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

// --- Kanban rezervací (Seznam): granulární sloupce + vyhledávání ----------------

/// Textové hledání v záložce Seznam (host + apartmán) – synchronizace z pole hledání na obrazovce rezervací.
final kanbanReservationsSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtrování rezervací podle jména hosta a názvu apartmánu.
List<ReservationRow> kanbanFilterReservationsBySearchQuery(
  List<ReservationRow> reservations,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return reservations;
  return reservations.where((r) {
    final guest = (r.guestName ?? '').toLowerCase();
    final apt = (r.apartmentName ?? '').toLowerCase();
    return guest.contains(q) || apt.contains(q);
  }).toList();
}

/// Mapování sloupce Kanbanu: [targetStatus] při dropu → které raw statusy v něm zobrazit.
///
/// PROČ duplicitně s UI: provider nesmí importovat screen; hodnoty musí zůstat v sync se sloupci Kanbanu na obrazovce.
const Map<String, List<String>> kanbanReservationColumnDisplayStatuses = {
  'new': ['new'],
  'confirmed': ['confirmed'],
  'checked_in': ['checked_in'],
  'checked_out': ['checked_out', 'cancelled'],
};

List<ReservationRow> kanbanReservationsForColumnTarget(
  List<ReservationRow> filtered,
  String targetStatus,
) {
  final statuses = kanbanReservationColumnDisplayStatuses[targetStatus];
  if (statuses == null) return const <ReservationRow>[];
  return filtered.where((r) => statuses.contains(r.status)).toList();
}

bool _reservationKanbanVisualEquals(ReservationRow a, ReservationRow b) {
  return a.id == b.id &&
      a.status == b.status &&
      a.guestName == b.guestName &&
      a.guestPhone == b.guestPhone &&
      a.apartmentName == b.apartmentName &&
      a.guestAdults == b.guestAdults &&
      a.guestChildren == b.guestChildren &&
      a.reservationSource == b.reservationSource &&
      a.referenceNumber == b.referenceNumber &&
      a.needsTransfer == b.needsTransfer &&
      a.internalNote == b.internalNote &&
      a.checkIn == b.checkIn &&
      a.checkOut == b.checkOut &&
      a.arrivalTime == b.arrivalTime &&
      a.departureTime == b.departureTime &&
      a.lastCommunicationTemplateContext == b.lastCommunicationTemplateContext &&
      a.lastCommunicationAt == b.lastCommunicationAt &&
      a.lastCommunicationTemplateId == b.lastCommunicationTemplateId;
}

/// Výřez rezervací jednoho sloupce Kanbanu s value equality (Riverpod překreslí jen při změně „svých“ řádků).
@immutable
class KanbanColumnReservations {
  const KanbanColumnReservations(this.reservations);
  final List<ReservationRow> reservations;

  factory KanbanColumnReservations.fromFiltered(List<ReservationRow> source) {
    if (source.isEmpty) return const KanbanColumnReservations(<ReservationRow>[]);
    return KanbanColumnReservations(List<ReservationRow>.unmodifiable(source));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! KanbanColumnReservations) return false;
    if (reservations.length != other.reservations.length) return false;
    for (var i = 0; i < reservations.length; i++) {
      if (!_reservationKanbanVisualEquals(reservations[i], other.reservations[i])) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        reservations.map(
          (e) => Object.hash(
            e.id,
            e.status,
            e.guestName,
            e.guestPhone,
            e.apartmentName,
            e.checkIn,
            e.checkOut,
            e.arrivalTime,
            e.departureTime,
            e.lastCommunicationAt,
          ),
        ),
      );
}

/// Rezervace pro jeden sloupec Kanbanu ([targetStatus] = cíl při drag & drop: new, confirmed, checked_in, checked_out).
///
/// Sleduje [adminReservationsProvider] a [kanbanReservationsSearchQueryProvider].
final reservationsBySystemStatusProvider =
    Provider.family<KanbanColumnReservations, String>((ref, targetStatus) {
  final async = ref.watch(adminReservationsProvider);
  final all = async.valueOrNull ?? const <ReservationRow>[];
  final q = ref.watch(kanbanReservationsSearchQueryProvider);
  final filtered = kanbanFilterReservationsBySearchQuery(all, q);
  final col = kanbanReservationsForColumnTarget(filtered, targetStatus);
  return KanbanColumnReservations.fromFiltered(col);
});

/// Zda je v Kanbanu po vyhledávání alespoň jedna rezervace (prázdný stav vs. nástěnka).
final kanbanHasVisibleReservationsProvider = Provider<bool>((ref) {
  final async = ref.watch(adminReservationsProvider);
  final all = async.valueOrNull ?? const <ReservationRow>[];
  final q = ref.watch(kanbanReservationsSearchQueryProvider);
  return kanbanFilterReservationsBySearchQuery(all, q).isNotEmpty;
});

/// Provider: rezervace související s klientem (parametr clientId).
///
/// LOGIKA: Tabulka [reservations] nemá přímo client_id. Pro majitele (owner) se
/// rezervace vážou přes byty: client.profile_id → apartment_owners.owner_id →
/// apartment_id → reservations.apartment_id. Pro externí/agency klienty vracíme
/// prázdný seznam (není jak je propojit).
///
/// Načte klienta z clientsFullListProvider, pokud je owner s profile_id, získá ID bytů
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

  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final res = await SupabaseService.safeFrom('reservations', tenantId)
      .select('id, apartment_id, reference_number, guest_name, guest_phone, guest_language, reservation_source, '
          'start_date, end_date, check_in, check_out, needs_transfer, status, '
          'guest_adults, guest_children, arrival_time, departure_time, internal_note, special_requests, '
          'deleted_at, '
          'last_communication_template_context, last_communication_at, last_communication_template_id, '
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

  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final res = await SupabaseService.safeFrom('reservations', tenantId)
      .select('id, apartment_id, reference_number, guest_name, guest_phone, guest_language, reservation_source, '
          'start_date, end_date, check_in, check_out, needs_transfer, status, '
          'guest_adults, guest_children, arrival_time, departure_time, internal_note, special_requests, '
          'deleted_at, '
          'last_communication_template_context, last_communication_at, last_communication_template_id, '
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
