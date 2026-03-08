import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/repositories/apartment/apartment_repository.dart';

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
    this.code,
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
    final codeRaw = (json['code'] as String?)?.trim();
    return ApartmentRow(
      id: json['id'] as String,
      name: (json['name'] as String?)?.trim() ?? '',
      address: (addr == null || addr.isEmpty) ? null : addr,
      keybox: (kb == null || kb.isEmpty) ? null : kb,
      code: (codeRaw == null || codeRaw.isEmpty) ? null : codeRaw,
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
      'code': code,
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
    String? code,
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
        code: code ?? this.code,
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
/// volá UI. ref.watch(apartmentsProvider) vrací AsyncValue<List<ApartmentRow>>.
/// Ostatní obrazovky (dropdowny, rezervace, úkoly) používají [apartmentsFullListProvider].
final apartmentsProvider =
    AsyncNotifierProvider<PaginatedApartmentsNotifier, List<ApartmentRow>>(
  PaginatedApartmentsNotifier.new,
);

/// Plný seznam apartmánů (až 500) pro dropdowny a jiné moduly.
///
/// PROČ: Formuláře (výběr bytu při úkolu, rezervaci, výběr bytu v reportech) potřebují
/// seznam bytů; stránkovaný provider vrací jen načtené stránky. Tento provider načte
/// jedním dotazem až 500 záznamů bez vyhledávání – pro výběr z dropdownu stačí.
final apartmentsFullListProvider =
    FutureProvider<List<ApartmentRow>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final raw = await ApartmentRepository.getPaginatedApartments(
    tenantId,
    limit: 500,
    offset: 0,
    searchQuery: null,
  );
  return raw.map((e) => ApartmentRow.fromJson(e)).toList();
});
