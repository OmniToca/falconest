import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/constants/apartment_rental_constants.dart';
import 'package:falconest/core/repositories/apartment/apartment_repository.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/utils/geo_json_point.dart';

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
    this.parkingInstructions,
    this.reviewLink,
    this.code,
    required this.tenantId,
    this.zoneId,
    this.status,
    this.checkInTime,
    this.checkOutTime,
    this.standardCleaningDuration,
    this.ownerNotes,
    this.monthlyManagementFee = 0.0,
    this.managedFrom,
    this.deletedAt,
    this.latitude,
    this.longitude,
    this.investmentTrackingEnabled = false,
    this.rentalMode = kApartmentRentalModeShortTerm,
    this.leaseStartDate,
    this.leaseEndDate,
    this.rentAmount = 0.0,
    this.rentDueDay = 1,
    this.rentCollectionMode = kApartmentRentCollectionModeNotification,
    this.rentTaskAssigneeId,
  });

  final String id;
  final String name;
  final String? address;
  final String? keybox;
  /// Instrukce k parkování nebo GPS navedení pro hosta.
  final String? parkingInstructions;
  /// URL odkaz na recenzi (Booking/Airbnb/Google).
  final String? reviewLink;
  /// Interní kód pro importy a podporu (např. SUN-01). Lidsky čitelný identifikátor.
  final String? code;
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
  /// Měsíční paušál za správu apartmánu v EUR (0 = neúčtuje se).
  final double monthlyManagementFee;
  /// První den měsíce, od kterého se paušál účtuje. Null = započítat vždy (zpětná kompatibilita).
  final DateTime? managedFrom;
  /// Soft delete: když není null, záznam je považován za smazaný (v UI se neukazuje).
  final DateTime? deletedAt;
  /// Zeměpisná šířka z `geo_location` (PostGIS → GeoJSON). Null = souřadnice nevyplněné.
  final double? latitude;
  /// Zeměpisná délka z `geo_location`.
  final double? longitude;
  /// Zapnuté sledování investičních metrik (`apartments.investment_tracking_enabled`).
  final bool investmentTrackingEnabled;
  /// Režim pronájmu: krátkodobý (STR) nebo dlouhodobý (`apartments.rental_mode`).
  final String rentalMode;
  /// Začátek platnosti nájemní smlouvy u dlouhodobého režimu (nullable).
  final DateTime? leaseStartDate;
  /// Konec platnosti nájemní smlouvy u dlouhodobého režimu (nullable).
  final DateTime? leaseEndDate;
  /// Měsíční nájem (dlouhodobý režim); u STR typicky 0.
  final double rentAmount;
  /// Den v měsíci splatnosti nájmu (1–31).
  final int rentDueDay;
  /// `notification` = připomínka v aplikaci; `task` = úkol [rent_collection] pro [rentTaskAssigneeId].
  final String rentCollectionMode;
  /// UUID profilu pracovníka pro režim úkolu (nullable).
  final String? rentTaskAssigneeId;

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
    final parkingInstructions = (json['parking_instructions'] as String?)?.trim();
    final reviewLink = (json['review_link'] as String?)?.trim();
    final notes = (json['owner_notes'] as String?)?.trim();
    final checkIn = (json['check_in_time'] as String?)?.trim();
    final checkOut = (json['check_out_time'] as String?)?.trim();
    final zoneRaw = json['zone_id'];
    final zoneId = (zoneRaw != null && zoneRaw.toString().trim().isNotEmpty) ? zoneRaw.toString().trim() : null;
    final codeRaw = (json['code'] as String?)?.trim();
    final feeRaw = json['monthly_management_fee'];
    double fee = 0.0;
    if (feeRaw != null) {
      if (feeRaw is num) {
        fee = feeRaw.toDouble();
      } else {
        fee = double.tryParse(feeRaw.toString()) ?? 0.0;
      }
    }
    final geo = GeoJsonPoint.parseFromPostgrest(json['geo_location']);
    final invRaw = json['investment_tracking_enabled'];
    final investmentTrackingEnabled = invRaw is bool
        ? invRaw
        : (invRaw?.toString().toLowerCase() == 'true');
    final modeRaw = (json['rental_mode']?.toString() ?? '').trim().toLowerCase();
    final rentalMode = modeRaw == kApartmentRentalModeLongTerm
        ? kApartmentRentalModeLongTerm
        : kApartmentRentalModeShortTerm;
    final rentAmtRaw = json['rent_amount'];
    double rentAmount = 0.0;
    if (rentAmtRaw != null) {
      if (rentAmtRaw is num) {
        rentAmount = rentAmtRaw.toDouble();
      } else {
        rentAmount = double.tryParse(rentAmtRaw.toString()) ?? 0.0;
      }
    }
    final rddRaw = json['rent_due_day'];
    int rentDueDay = 1;
    if (rddRaw is int) {
      rentDueDay = rddRaw.clamp(1, 31);
    } else if (rddRaw is num) {
      rentDueDay = rddRaw.toInt().clamp(1, 31);
    } else if (rddRaw != null) {
      rentDueDay = int.tryParse(rddRaw.toString())?.clamp(1, 31) ?? 1;
    }
    final rcmRaw = (json['rent_collection_mode']?.toString() ?? '').trim().toLowerCase();
    final rentCollectionMode = rcmRaw == kApartmentRentCollectionModeTask
        ? kApartmentRentCollectionModeTask
        : kApartmentRentCollectionModeNotification;
    final rta = json['rent_task_assignee_id'];
    final rentTaskAssigneeId = (rta != null && rta.toString().trim().isNotEmpty)
        ? rta.toString().trim()
        : null;
    return ApartmentRow(
      id: json['id'] as String,
      name: (json['name'] as String?)?.trim() ?? '',
      address: (addr == null || addr.isEmpty) ? null : addr,
      keybox: (kb == null || kb.isEmpty) ? null : kb,
      parkingInstructions: (parkingInstructions == null || parkingInstructions.isEmpty)
          ? null
          : parkingInstructions,
      reviewLink: (reviewLink == null || reviewLink.isEmpty) ? null : reviewLink,
      code: (codeRaw == null || codeRaw.isEmpty) ? null : codeRaw,
      tenantId: json['tenant_id'] as String? ?? '',
      zoneId: zoneId,
      status: _parseStatus(json['status']),
      checkInTime: (checkIn == null || checkIn.isEmpty) ? '15:00' : checkIn,
      checkOutTime: (checkOut == null || checkOut.isEmpty) ? '10:00' : checkOut,
      standardCleaningDuration: duration ?? 120,
      ownerNotes: (notes == null || notes.isEmpty) ? null : notes,
      monthlyManagementFee: fee,
      managedFrom: _parseOptionalDateTime(json['managed_from']),
      deletedAt: _parseOptionalDateTime(json['deleted_at']),
      latitude: geo?.latitude,
      longitude: geo?.longitude,
      investmentTrackingEnabled: investmentTrackingEnabled,
      rentalMode: rentalMode,
      leaseStartDate: _parseLeaseDate(json['lease_start_date']),
      leaseEndDate: _parseLeaseDate(json['lease_end_date']),
      rentAmount: rentAmount,
      rentDueDay: rentDueDay,
      rentCollectionMode: rentCollectionMode,
      rentTaskAssigneeId: rentTaskAssigneeId,
    );
  }

  /// Parsování `date` z PostgREST na kalendářní den v UTC (parita s `NullableIsoDateOnlyConverter`).
  static DateTime? _parseLeaseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return DateTime.utc(raw.year, raw.month, raw.day);
    if (raw is String) {
      final d = DateTime.tryParse(raw);
      if (d != null) return DateTime.utc(d.year, d.month, d.day);
    }
    return null;
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
      'parking_instructions': parkingInstructions,
      'review_link': reviewLink,
      'code': code,
      'status': status ?? _statusFallback,
      'check_in_time': checkInTime ?? '15:00',
      'check_out_time': checkOutTime ?? '10:00',
      'standard_cleaning_duration': standardCleaningDuration ?? 120,
      'owner_notes': ownerNotes,
      'monthly_management_fee': monthlyManagementFee,
      'managed_from': managedFrom != null
          ? '${managedFrom!.year}-${managedFrom!.month.toString().padLeft(2, '0')}-01'
          : null,
      'geo_location': GeoJsonPoint.toPostgrestJson(latitude, longitude),
      'investment_tracking_enabled': investmentTrackingEnabled,
      'rental_mode': rentalMode,
      'lease_start_date': _leaseDateToPg(leaseStartDate),
      'lease_end_date': _leaseDateToPg(leaseEndDate),
      'rent_amount': rentAmount,
      'rent_due_day': rentDueDay,
      'rent_collection_mode': rentCollectionMode,
      'rent_task_assignee_id': rentTaskAssigneeId,
    };
    if (forInsert) {
      map['tenant_id'] = tenantId;
    }
    return map;
  }

  /// Alias pro konzistentní pojmenování serializace napříč modely.
  Map<String, dynamic> toJson({bool forInsert = false}) =>
      toMap(forInsert: forInsert);

  static String? _leaseDateToPg(DateTime? d) {
    if (d == null) return null;
    final u = DateTime.utc(d.year, d.month, d.day);
    return '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
  }

  ApartmentRow copyWith({
    String? id,
    String? name,
    String? address,
    String? keybox,
    String? parkingInstructions,
    String? reviewLink,
    String? code,
    String? tenantId,
    String? zoneId,
    String? status,
    String? checkInTime,
    String? checkOutTime,
    int? standardCleaningDuration,
    String? ownerNotes,
    double? monthlyManagementFee,
    DateTime? managedFrom,
    DateTime? deletedAt,
    double? latitude,
    double? longitude,
    bool? investmentTrackingEnabled,
    String? rentalMode,
    DateTime? leaseStartDate,
    DateTime? leaseEndDate,
    double? rentAmount,
    int? rentDueDay,
    String? rentCollectionMode,
    String? rentTaskAssigneeId,
  }) =>
      ApartmentRow(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        keybox: keybox ?? this.keybox,
        parkingInstructions: parkingInstructions ?? this.parkingInstructions,
        reviewLink: reviewLink ?? this.reviewLink,
        code: code ?? this.code,
        tenantId: tenantId ?? this.tenantId,
        zoneId: zoneId ?? this.zoneId,
        status: status ?? this.status,
        checkInTime: checkInTime ?? this.checkInTime,
        checkOutTime: checkOutTime ?? this.checkOutTime,
        standardCleaningDuration: standardCleaningDuration ?? this.standardCleaningDuration,
        ownerNotes: ownerNotes ?? this.ownerNotes,
        monthlyManagementFee: monthlyManagementFee ?? this.monthlyManagementFee,
        managedFrom: managedFrom ?? this.managedFrom,
        deletedAt: deletedAt ?? this.deletedAt,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        investmentTrackingEnabled: investmentTrackingEnabled ?? this.investmentTrackingEnabled,
        rentalMode: rentalMode ?? this.rentalMode,
        leaseStartDate: leaseStartDate ?? this.leaseStartDate,
        leaseEndDate: leaseEndDate ?? this.leaseEndDate,
        rentAmount: rentAmount ?? this.rentAmount,
        rentDueDay: rentDueDay ?? this.rentDueDay,
        rentCollectionMode: rentCollectionMode ?? this.rentCollectionMode,
        rentTaskAssigneeId: rentTaskAssigneeId ?? this.rentTaskAssigneeId,
      );
}

/// Příznak, zda se načítá další stránka (nekonečný scroll).
/// Notifier ho nastavuje v loadMore() pro zobrazení indikátoru na konci seznamu.
final apartmentsLoadingMoreProvider = StateProvider<bool>((ref) => false);

/// Notifier pro stránkovaný seznam apartmánů se server-side vyhledáváním.
///
/// PROČ: Při 100+ bytech nelze stahovat všechny naráz. build() načte první stránku,
/// loadMore() připojuje další, search(query) resetuje a načte s filtrem.
class PaginatedApartmentsNotifier extends AsyncNotifier<List<ApartmentRow>> {
  int _offset = 0;
  static const int _limit = 50;
  bool _hasMore = true;
  String _searchQuery = '';

  @override
  Future<List<ApartmentRow>> build() async {
    _offset = 0;
    _hasMore = true;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return [];

    final raw = await ApartmentRepository.getPaginatedApartments(
      tenantId,
      limit: _limit,
      offset: 0,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );
    final list = raw.map((e) => ApartmentRow.fromJson(e)).toList();
    _offset = list.length;
    _hasMore = list.length >= _limit;
    return list;
  }

  /// Načte další stránku a připojí ji k aktuálnímu seznamu.
  Future<void> loadMore() async {
    if (!_hasMore) return;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;

    ref.read(apartmentsLoadingMoreProvider.notifier).state = true;
    try {
      final raw = await ApartmentRepository.getPaginatedApartments(
        tenantId,
        limit: _limit,
        offset: _offset,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );
      final list = raw.map((e) => ApartmentRow.fromJson(e)).toList();
      _offset += list.length;
      _hasMore = list.length >= _limit;

      final state = this.state;
      if (state.hasValue && list.isNotEmpty) {
        this.state = AsyncValue.data([...state.value!, ...list]);
      }
    } finally {
      ref.read(apartmentsLoadingMoreProvider.notifier).state = false;
    }
  }

  /// Server-side vyhledávání: reset offsetu, nastaví dotaz a načte první stránku.
  Future<void> search(String query) async {
    _searchQuery = query.trim();
    _offset = 0;
    _hasMore = true;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }
}

/// Provider stránkovaného seznamu apartmánů pro obrazovku Apartmány.
///
/// Používá PaginatedApartmentsNotifier – build() načte první stránku, loadMore() a search()
/// volá UI. ref.watch(apartmentsProvider) vrací AsyncValue se seznamem [ApartmentRow].
/// Ostatní obrazovky (dropdowny, rezervace, úkoly) používají [apartmentsFullListProvider].
final apartmentsProvider =
    AsyncNotifierProvider<PaginatedApartmentsNotifier, List<ApartmentRow>>(
  PaginatedApartmentsNotifier.new,
);

/// Horní limit pro `apartmentsFullListProvider`.
///
/// PROČ: Tento provider slouží pro dropdowny a další moduly napříč Adminem.
/// U velkých tenantů nesmíme potichu ořezat seznam na příliš nízkém limitu.
const int apartmentsFullListProviderLimit = 5000;

/// Jestli se při načítání `apartmentsFullListProvider` narazilo na limit.
///
/// UI pak zobrazí varování, že data mohou být neúplná (aplikační ořez).
final apartmentsDataLimitReachedProvider = StateProvider<bool>((ref) => false);

/// Plný seznam apartmánů pro dropdowny a jiné moduly (jeden HTTP dotaz, řazení podle názvu).
///
/// PROČ: Dříve tichý limit 500 krátil seznam u velkých agentur. Obrazovka Apartmány má vlastní
/// stránkování ([apartmentsProvider]); tento provider slouží hlavně výběrovým polím, kde
/// nestříháme na 500 – držíme horní mez 2000 (stejný mechanismus jako stránkování, jedna „stránka“).
/// Při více než 2000 bytech zůstává doporučení použít vyhledávání na stránce Apartmány a rozšířit UI v budoucnu.
final apartmentsFullListProvider =
    FutureProvider<List<ApartmentRow>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    ref.read(apartmentsDataLimitReachedProvider.notifier).state = false;
    return [];
  }

  try {
    final raw = await ApartmentRepository.getPaginatedApartments(
      tenantId,
      limit: apartmentsFullListProviderLimit,
      offset: 0,
      searchQuery: null,
    );

    // PROČ: I když máme RLS, server i klient mohou mít limity.
    // Pokud je vrácený počet >= limit, data pravděpodobně nejsou kompletní.
    ref.read(apartmentsDataLimitReachedProvider.notifier).state =
        raw.length >= apartmentsFullListProviderLimit;

    return raw.map((e) => ApartmentRow.fromJson(e)).toList();
  } catch (e, st) {
    AppLogger.error('apartmentsFullListProvider: načtení apartmánů selhalo', e, st);
    ref.read(apartmentsDataLimitReachedProvider.notifier).state = false;
    return [];
  }
});
