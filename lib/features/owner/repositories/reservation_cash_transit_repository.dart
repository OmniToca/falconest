import 'dart:math' as math;

import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/owner/models/owner_cash_transit_settlement.dart';
import 'package:flutter/foundation.dart';

/// Fáze průtokové hotovosti za ubytování (odvozeno z knihy + settlement, bez „planned“ řádků v ledgeru).
enum ReservationCashTransitPhase {
  /// U úkolů rezervace není plánovaný průtok (`metadata.transit_amount_to_collect`).
  notApplicable,

  /// Plán existuje, v knize není COLLECTED pro tuto rezervaci.
  awaitingCollection,

  /// COLLECTED existuje; není settlement a není HANDED s `reservation_id` této rezervace.
  ///
  /// POZN.: `HANDED_TO_AGENCY` bez `reservation_id` tento stav neukončí – při převzetí hotovosti zvolte rezervaci v admin dialogu.
  withWorker,

  /// Existuje `HANDED_TO_AGENCY` s `reservation_id` = rezervace, bez settlement.
  atAgencyVault,

  /// Záznam v `owner_cash_transit_settlements`.
  settledToOwner,
}

/// Stav průtokové hotovosti pro jednu rezervaci (lidský přehled pro majitelku / admin).
class ReservationCashTransitSnapshot {
  const ReservationCashTransitSnapshot({
    required this.phase,
    this.plannedAmount,
    this.currencyCode = 'EUR',
    this.collectedTotal,
    this.settledAmount,
    this.settledAt,
  });

  final ReservationCashTransitPhase phase;

  /// Max. z `tasks.metadata.transit_amount_to_collect` u úkolů rezervace.
  final double? plannedAmount;
  final String currencyCode;

  /// Součet průtokové části z COLLECTED (`transit_portion` nebo dopočet z metadat).
  final double? collectedTotal;
  final double? settledAmount;
  final DateTime? settledAt;
}

/// Načte a vyhodnotí fázi průtokové hotovosti pro [reservationId] v rámci tenanta.
///
/// Repozitář žije ve feature `owner`, protože data čtou i majitelé (RLS); admin ho používá z finance UI.
class ReservationCashTransitRepository {
  ReservationCashTransitRepository._();

  /// Sjednocení aliasů sloupců mezi základním a rozšířeným schématem (`created_by`→`settled_by`, `note`/`notes`).
  ///
  /// PROČ: Model čte `note` i volitelné rozšířené klíče; tato mapa zajišťuje zpětnou kompatibilitu starých odpovědí.
  static Map<String, dynamic> _normalizeSettlementJson(
    Map<String, dynamic> json,
  ) {
    final m = Map<String, dynamic>.from(json);
    if (m['settled_by'] == null && m['created_by'] != null) {
      m['settled_by'] = m['created_by'];
    }
    // DB může vracet `note` nebo legacy `notes`; @JsonKey(name: 'note') očekává klíč `note`.
    if (m['note'] == null && m['notes'] != null) {
      m['note'] = m['notes'];
    }
    m.putIfAbsent('status', () => 'available');
    m.putIfAbsent('currency', () => 'EUR');
    return m;
  }

  /// Vylepšení UX: Přidání jména hosta k datům pobytu pro lepší orientaci majitele.
  static const String _settlementSelectWithReservation =
      '*, reservations(guest_name, start_date, end_date)';

  static DateTime? _parseReservationDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// Z vnořeného `reservations` z PostgREST odpovědi vytáhne údaje pro UI dropdownu.
  static ({
    String? guestName,
    DateTime? stayStart,
    DateTime? stayEnd,
  })? _reservationFieldsFromEmbeddedJson(dynamic embedded) {
    if (embedded is! Map) return null;
    final map = Map<String, dynamic>.from(embedded);
    final guestRaw = map['guest_name']?.toString().trim();
    final guestName =
        guestRaw != null && guestRaw.isNotEmpty ? guestRaw : null;
    return (
      guestName: guestName,
      stayStart: _parseReservationDate(map['start_date']),
      stayEnd: _parseReservationDate(map['end_date']),
    );
  }

  /// Parsování řádků settlementů; poškozený řádek přeskočíme, aby majitelův dashboard nespadl na jedné chybě JSON.
  static List<OwnerCashTransitSettlement> _parseSettlementRows(dynamic rows) {
    final list = rows is List ? rows : const <dynamic>[];
    final out = <OwnerCashTransitSettlement>[];
    for (final e in list) {
      if (e is! Map) continue;
      try {
        final rowMap = Map<String, dynamic>.from(e);
        final embedded = _reservationFieldsFromEmbeddedJson(
          rowMap.remove('reservations'),
        );
        var settlement = OwnerCashTransitSettlement.fromJson(
          _normalizeSettlementJson(rowMap),
        );
        if (embedded != null) {
          settlement = settlement.copyWith(
            guestName: embedded.guestName ?? settlement.guestName,
            reservationStayStart:
                embedded.stayStart ?? settlement.reservationStayStart,
            reservationStayEnd: embedded.stayEnd ?? settlement.reservationStayEnd,
          );
        }
        out.add(settlement);
      } catch (e, st) {
        // PROČ: Supabase může vrátit neočekávaný tvar; raději vynechat řádek než shodit celý provider.
        debugPrint('Chyba při čtení settlementu: $e');
        debugPrint('$st');
      }
    }
    return out;
  }

  /// Diagnostika dvojnásobného zůstatku: vypíše surové řádky, duplicitní `id` a průběžný součet částek.
  ///
  /// PROČ: Na webu owner portál nečte Isar — pokud je součet 2× správné hodnoty, typicky jde o duplicitní
  /// řádky v `owner_cash_transit_settlements` nebo o stejný řádek dvakrát v raw odpovědi (OR dotaz).
  static void _debugLogOwnerBalancePipeline({
    required String phase,
    required String tenantId,
    required String ownerProfileId,
    required List<OwnerCashTransitSettlement> settlements,
    int? rawSupabaseRowCount,
    String? queryHint,
    Map<String, Object?>? extra,
  }) {
    if (!kDebugMode) return;
    final buf = StringBuffer(
      'OwnerBalanceDebug[$phase] tenantId=$tenantId ownerProfileId=$ownerProfileId',
    );
    if (queryHint != null) buf.write(' query=$queryHint');
    if (rawSupabaseRowCount != null) {
      buf.write(' rawSupabaseRows=$rawSupabaseRowCount');
    }
    buf.write(' parsedCount=${settlements.length}');
    if (extra != null) {
      for (final e in extra.entries) {
        buf.write(' ${e.key}=${e.value}');
      }
    }
    AppLogger.debug(buf.toString());
    AppLogger.debug(
      'OwnerBalanceDebug[$phase] lokální Isar/Drift: nepoužito (owner Vyúčtování na webu = pouze Supabase)',
    );

    final seenIds = <String, int>{};
    var runningSum = 0.0;
    for (var i = 0; i < settlements.length; i++) {
      final s = settlements[i];
      runningSum += s.amount;
      final id = s.id.trim();
      seenIds[id] = (seenIds[id] ?? 0) + 1;
      AppLogger.debug(
        'OwnerBalanceDebug[$phase] row[$i] id=$id amount=${s.amount} ${s.currency} '
        'status=${s.status} reservation_id=${s.reservationId ?? "null"} '
        'apartment_id=${s.apartmentId ?? "null"} task_id=${s.taskId ?? "null"} '
        'runningSum=$runningSum',
      );
    }
    final dupIds =
        seenIds.entries.where((e) => e.value > 1).map((e) => '${e.key}(×${e.value})').toList();
    if (dupIds.isNotEmpty) {
      AppLogger.debug(
        'OwnerBalanceDebug[$phase] VAROVÁNÍ: duplicitní settlement id v seznamu (může vysvětlit 2× zůstatek): ${dupIds.join(", ")}',
      );
    }
    AppLogger.debug('OwnerBalanceDebug[$phase] finální součet amount=$runningSum');
  }

  static double? _amountToCollectFromMetadata(Map<String, dynamic>? meta) {
    if (meta == null) return null;
    final raw = meta['amount_to_collect'];
    final v = (raw is num)
        ? raw.toDouble()
        : (raw != null ? double.tryParse(raw.toString()) : null);
    if (v == null || v <= 0) return null;
    return v;
  }

  /// Plán průtokové hotovosti – pouze `transit_amount_to_collect` (ne příjem agentury).
  static double? _transitAmountToCollectFromMetadata(
    Map<String, dynamic>? meta,
  ) {
    if (meta == null) return null;
    final raw = meta['transit_amount_to_collect'];
    final v = (raw is num)
        ? raw.toDouble()
        : (raw != null ? double.tryParse(raw.toString()) : null);
    if (v == null || v <= 0) return null;
    return v;
  }

  static double _collectedTransitPortion({
    required Map<String, dynamic> txRow,
    required Map<String, Map<String, dynamic>> taskMetaById,
  }) {
    final amount = (txRow['amount'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) return 0;

    final explicit = txRow['transit_portion'];
    if (explicit != null) {
      final e = (explicit is num)
          ? explicit.toDouble()
          : double.tryParse(explicit.toString()) ?? 0;
      return e > 0 ? e : 0;
    }

    final taskId = txRow['task_id']?.toString();
    final meta = (taskId != null && taskId.isNotEmpty)
        ? taskMetaById[taskId]
        : null;
    final tPlan = _transitAmountToCollectFromMetadata(meta);
    final aPlan = _amountToCollectFromMetadata(meta);
    final hasTransitKey =
        meta?.containsKey('transit_amount_to_collect') ?? false;

    if (tPlan != null && tPlan > 0) {
      final agency = aPlan ?? 0;
      final afterAgency = math.max(0.0, amount - agency);
      final cap = math.min(afterAgency, tPlan);
      return cap > 0 ? cap : 0;
    }

    if (!hasTransitKey && (aPlan != null && aPlan > 0)) {
      return amount;
    }
    return 0;
  }

  /// Všechny settlement záznamy pro jednu rezervaci (obvykle 0–1 řádek).
  static Future<List<OwnerCashTransitSettlement>>
  fetchSettlementsForReservation({
    required String tenantId,
    required String reservationId,
  }) async {
    final rid = reservationId.trim();
    final tid = tenantId.trim();
    if (rid.isEmpty || tid.isEmpty) return [];

    final safeSettlements = SupabaseService.safeFrom(
      'owner_cash_transit_settlements',
      tid,
    );
    final rows = await safeSettlements.select().eq('reservation_id', rid);
    return _parseSettlementRows(rows);
  }

  /// Settlementy napříč rezervacemi na bytech, kde je [ownerProfileId] vlastníkem (`apartment_owners`).
  static Future<List<OwnerCashTransitSettlement>>
  listSettlementsForOwnerProfile({
    required String tenantId,
    required String ownerProfileId,
  }) async {
    final tid = tenantId.trim();
    final oid = ownerProfileId.trim();
    if (tid.isEmpty || oid.isEmpty) return [];

    final safeAo = SupabaseService.safeFrom('apartment_owners', tid);
    final aoRows = await safeAo
        .select('apartment_id')
        .eq('owner_id', oid)
        .isFilter('deleted_at', null);

    final aptIds = <String>[];
    for (final r in (aoRows is List ? aoRows : const <dynamic>[])) {
      if (r is! Map) continue;
      final aid = r['apartment_id']?.toString();
      if (aid != null && aid.isNotEmpty) aptIds.add(aid);
    }
    if (aptIds.isEmpty) {
      _debugLogOwnerBalancePipeline(
        phase: 'listSettlementsForOwnerProfile',
        tenantId: tid,
        ownerProfileId: oid,
        settlements: const [],
        extra: {'reason': 'žádné apartment_id v apartment_owners'},
      );
      return [];
    }

    final safeRes = SupabaseService.safeFrom('reservations', tid);
    final resRows = await safeRes
        .select('id')
        .inFilter('apartment_id', aptIds)
        .isFilter('deleted_at', null);

    final resIds = <String>[];
    for (final r in (resRows is List ? resRows : const <dynamic>[])) {
      if (r is! Map) continue;
      final id = r['id']?.toString();
      if (id != null && id.isNotEmpty) resIds.add(id);
    }

    final safeSettlements = SupabaseService.safeFrom(
      'owner_cash_transit_settlements',
      tid,
    );
    dynamic rows;
    String queryHint;
    // Vylepšení UX: Přidání jména hosta k datům pobytu pro lepší orientaci majitele.
    if (resIds.isEmpty) {
      queryHint = 'apartment_id.in(${aptIds.length} bytů)';
      rows = await safeSettlements
          .select(_settlementSelectWithReservation)
          .inFilter('apartment_id', aptIds)
          .order('settled_at', ascending: false);
    } else {
      final resCsv = resIds.join(',');
      final aptCsv = aptIds.join(',');
      queryHint =
          'OR reservation_id.in(${resIds.length}) OR apartment_id.in(${aptIds.length})';
      // PROČ: Nové settlementy z dlouhodobého nájmu mohou mít `reservation_id=NULL`, proto musíme
      // vracet jak větev přes rezervaci, tak větev přes přímý `apartment_id`.
      rows = await safeSettlements
          .select(_settlementSelectWithReservation)
          .or('reservation_id.in.($resCsv),apartment_id.in.($aptCsv)')
          .order('settled_at', ascending: false);
    }
    final rawList = rows is List ? rows : const <dynamic>[];
    if (kDebugMode) {
      AppLogger.debug(
        'OwnerBalanceDebug[supabase_raw] tabulka=owner_cash_transit_settlements '
        'počet řádků=${rawList.length} dotaz=$queryHint',
      );
      for (var i = 0; i < rawList.length; i++) {
        final e = rawList[i];
        if (e is! Map) continue;
        AppLogger.debug(
          'OwnerBalanceDebug[supabase_raw] raw[$i]=${Map<String, dynamic>.from(e)}',
        );
      }
    }
    final parsed = _parseSettlementRows(rows);
    _debugLogOwnerBalancePipeline(
      phase: 'listSettlementsForOwnerProfile',
      tenantId: tid,
      ownerProfileId: oid,
      settlements: parsed,
      rawSupabaseRowCount: rawList.length,
      queryHint: queryHint,
      extra: {
        'apartmentOwnersCount': aptIds.length,
        'reservationIdsCount': resIds.length,
      },
    );
    return parsed;
  }

  /// Stavy žádosti o dispozici, které **rezervují částku** z poolu settlementů (ne celý řádek).
  ///
  /// PROČ: Schválená žádost na 250 EUR nesmí „zmizet“ celých 666 EUR ze zůstatku – drží jen
  /// nevyčerpaný zbytek (`amount - used_amount`), např. po částečném umoření faktury.
  static const List<String> _dispositionStatusesReservingBalance = [
    'approved',
    'partially_completed',
    'ready_for_pickup',
  ];

  /// Součet uznaných settlementů majitele v cílové měně (bez `fully_disbursed`).
  static double _sumSettlementPoolAmount({
    required List<OwnerCashTransitSettlement> settlements,
    required String targetCurrency,
  }) {
    final targetCur = targetCurrency.trim().toUpperCase();
    return settlements
        .where((s) {
          if (s.currency.trim().toUpperCase() != targetCur) return false;
          if (s.status == 'fully_disbursed') return false;
          return true;
        })
        .fold<double>(0, (a, s) => a + s.amount);
  }

  /// Načte rezervované částky podle `settlement_id` z aktivních žádostí majitele (`tenant_id`).
  ///
  /// Klíč = settlement_id, hodnota = součet `(amount - used_amount)` všech žádostí na daný settlement.
  static Future<Map<String, double>> _reservedAmountBySettlementId({
    required String tenantId,
    required String ownerProfileId,
  }) async {
    final tid = tenantId.trim();
    final oid = ownerProfileId.trim();
    if (tid.isEmpty || oid.isEmpty) return {};

    final safeDisp = SupabaseService.safeFrom(
      'owner_cash_disposition_requests',
      tid,
    );
    final dispRows = await safeDisp
        .select('settlement_id, amount, used_amount, status')
        .eq('owner_profile_id', oid)
        .inFilter('status', _dispositionStatusesReservingBalance);

    final bySettlement = <String, double>{};
    const eps = 1e-9;
    for (final r in (dispRows is List ? dispRows : const <dynamic>[])) {
      if (r is! Map) continue;
      final sid = r['settlement_id']?.toString().trim();
      if (sid == null || sid.isEmpty) continue;
      final amount = (r['amount'] as num?)?.toDouble() ?? 0;
      final used = (r['used_amount'] as num?)?.toDouble() ?? 0;
      final hold = math.max(0.0, amount - used);
      if (hold <= eps) continue;
      bySettlement[sid] = (bySettlement[sid] ?? 0) + hold;
    }
    return bySettlement;
  }

  /// Celková rezervace majitele = součet nevyčerpaných částek ze schválených žádostí (všechny settlementy).
  static double _sumTotalReservedDispositionAmount(
    Map<String, double> reservedBySettlement,
  ) {
    return reservedBySettlement.values.fold<double>(0, (a, v) => a + v);
  }

  /// Klíč pobytu pro sloučení více řádků `owner_cash_transit_settlements` (kladný + záporné zápočty).
  static String _stayGroupKey(OwnerCashTransitSettlement s) {
    final rid = s.reservationId?.trim();
    if (rid != null && rid.isNotEmpty) return 'res:$rid';
    final apt = s.apartmentId?.trim() ?? '';
    final task = s.taskId?.trim() ?? '';
    if (apt.isNotEmpty || task.isNotEmpty) {
      return 'stay:apt:$apt:task:$task';
    }
    return 'settlement:${s.id}';
  }

  /// Sloučení všech finančních pohybů pro danou rezervaci (včetně záporných zápočtů) pro výpočet reálného zůstatku pobytu.
  static double _netPoolForStayGroup(List<OwnerCashTransitSettlement> members) {
    return members.fold<double>(0, (sum, s) => sum + s.amount);
  }

  /// Součet rezervací ze žádostí přes všechna `settlement_id` patřící ke stejnému pobytu.
  static double _reservedForStayGroup(
    List<OwnerCashTransitSettlement> members,
    Map<String, double> reservedBySettlement,
  ) {
    return members.fold<double>(
      0,
      (sum, s) => sum + (reservedBySettlement[s.id] ?? 0),
    );
  }

  /// Dostupná částka pro jeden pobyt: Σ amount (včetně záporných) − Σ rezervací žádostí; volitelný strop globálním zůstatkem.
  static double _availableAmountForStayGroup({
    required List<OwnerCashTransitSettlement> members,
    required Map<String, double> reservedBySettlement,
    double? globalAvailableCap,
  }) {
    final net = _netPoolForStayGroup(members);
    final reserved = _reservedForStayGroup(members, reservedBySettlement);
    var remaining = math.max(0.0, net - reserved);
    if (globalAvailableCap != null) {
      remaining = math.min(remaining, math.max(0.0, globalAvailableCap));
    }
    return remaining;
  }

  /// Reprezentativní řádek pro dropdown a novou žádost (preferuje kladný settlement s nejvyšší částkou).
  static OwnerCashTransitSettlement _pickRepresentativeForStayGroup(
    List<OwnerCashTransitSettlement> members,
  ) {
    OwnerCashTransitSettlement? bestPositive;
    for (final s in members) {
      if (s.amount <= 0) continue;
      if (bestPositive == null || s.amount > bestPositive.amount) {
        bestPositive = s;
      }
    }
    return bestPositive ?? members.first;
  }

  static Map<String, List<OwnerCashTransitSettlement>> _groupSettlementsByStay({
    required List<OwnerCashTransitSettlement> settlements,
    required String targetCurrency,
  }) {
    final targetCur = targetCurrency.trim().toUpperCase();
    final groups = <String, List<OwnerCashTransitSettlement>>{};
    for (final s in settlements) {
      if (s.currency.trim().toUpperCase() != targetCur) continue;
      if (s.status == 'fully_disbursed') continue;
      final key = _stayGroupKey(s);
      groups.putIfAbsent(key, () => []).add(s);
    }
    return groups;
  }

  /// Settlementy majitele s „volnou“ částkou v dané měně (stejná logika jako [getAvailableBalanceForOwner]).
  ///
  /// PROČ: UI potřebuje jednu položku na pobyt; kladný i záporné řádky se stejným `reservation_id`
  /// se sloučí před odečtem žádostí o dispozici.
  static Future<List<OwnerCashTransitSettlement>>
  listAvailableSettlementsForOwner({
    required String tenantId,
    required String ownerProfileId,
    String currencyCode = 'EUR',
  }) async {
    final settlements = await listSettlementsForOwnerProfile(
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
    );
    if (settlements.isEmpty) return [];

    final targetCur = currencyCode.trim().toUpperCase();
    final reservedBySettlement = await _reservedAmountBySettlementId(
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
    );

    final globalCap = math.max(
      0.0,
      _sumSettlementPoolAmount(
        settlements: settlements,
        targetCurrency: targetCur,
      ) -
          _sumTotalReservedDispositionAmount(reservedBySettlement),
    );

    const eps = 1e-9;
    final groups = _groupSettlementsByStay(
      settlements: settlements,
      targetCurrency: targetCur,
    );

    // Sloučení všech finančních pohybů pro danou rezervaci (včetně záporných zápočtů) pro výpočet reálného zůstatku pobytu.
    final filtered = <OwnerCashTransitSettlement>[];
    for (final entry in groups.entries) {
      final members = entry.value;
      if (members.isEmpty) continue;

      final remaining = _availableAmountForStayGroup(
        members: members,
        reservedBySettlement: reservedBySettlement,
        globalAvailableCap: globalCap,
      );
      if (remaining <= eps) continue;

      final representative = _pickRepresentativeForStayGroup(members);
      filtered.add(
        representative.copyWith(
          availableAmount: remaining,
          guestName: representative.guestName ??
              members
                  .map((m) => m.guestName?.trim())
                  .whereType<String>()
                  .where((n) => n.isNotEmpty)
                  .firstOrNull,
          reservationStayStart: representative.reservationStayStart ??
              members
                  .map((m) => m.reservationStayStart)
                  .whereType<DateTime>()
                  .firstOrNull,
          reservationStayEnd: representative.reservationStayEnd ??
              members
                  .map((m) => m.reservationStayEnd)
                  .whereType<DateTime>()
                  .firstOrNull,
        ),
      );

      if (kDebugMode) {
        AppLogger.debug(
          'OwnerBalanceDebug[stay_group] key=${entry.key} net=${_netPoolForStayGroup(members)} '
          'reserved=${_reservedForStayGroup(members, reservedBySettlement)} '
          'remaining=$remaining globalCap=$globalCap settlementIds=${members.map((m) => m.id).join(",")}',
        );
      }
    }

    if (kDebugMode) {
      AppLogger.debug(
        'OwnerBalanceDebug[disposition_reserve] tenantId=$tenantId '
        'reservedBySettlement=$reservedBySettlement globalCap=$globalCap',
      );
    }
    _debugLogOwnerBalancePipeline(
      phase: 'listAvailableSettlements_afterFilter',
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
      settlements: filtered,
      extra: {
        'totalReserved': _sumTotalReservedDispositionAmount(reservedBySettlement),
        'globalCap': globalCap,
        'formula': 'sum(amount per reservation_id) - sum(reserved per group), cap global',
        'groupCount': groups.length,
      },
    );

    return _mergeReservationStayDates(
      tenantId: tenantId,
      settlements: filtered,
    );
  }

  /// Maximální částka nové žádosti vázaná na jeden settlement (po rezervacích z jiných žádostí).
  static Future<double> getAvailableAmountForSettlement({
    required String tenantId,
    required String ownerProfileId,
    required String settlementId,
    String currencyCode = 'EUR',
  }) async {
    final sid = settlementId.trim();
    if (sid.isEmpty) return 0;

    final settlements = await listSettlementsForOwnerProfile(
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
    );
    OwnerCashTransitSettlement? match;
    for (final s in settlements) {
      if (s.id == sid) {
        match = s;
        break;
      }
    }
    if (match == null) return 0;
    if (match.currency.trim().toUpperCase() !=
        currencyCode.trim().toUpperCase()) {
      return 0;
    }
    if (match.status == 'fully_disbursed') return 0;

    final targetCur = currencyCode.trim().toUpperCase();
    final reservedBySettlement = await _reservedAmountBySettlementId(
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
    );

    final globalCap = math.max(
      0.0,
      _sumSettlementPoolAmount(
        settlements: settlements,
        targetCurrency: targetCur,
      ) -
          _sumTotalReservedDispositionAmount(reservedBySettlement),
    );

    final groups = _groupSettlementsByStay(
      settlements: settlements,
      targetCurrency: targetCur,
    );
    final groupKey = _stayGroupKey(match);
    final members = groups[groupKey];
    if (members == null || members.isEmpty) return 0;

    return _availableAmountForStayGroup(
      members: members,
      reservedBySettlement: reservedBySettlement,
      globalAvailableCap: globalCap,
    );
  }

  /// Doplní termíny pobytu a jméno hosta z tabulky `reservations` (záloha, pokud embed v selectu chybí).
  ///
  /// PROČ: V dropdownu žádosti o dispozici nesmíme ukazovat UUID rezervace; majitel rozumí termínům pobytu.
  /// Jedno dotazování po filtru zůstatku – RLS rezervací je stejná jako u výběru `reservation_id` v [listSettlementsForOwnerProfile].
  static Future<List<OwnerCashTransitSettlement>> _mergeReservationStayDates({
    required String tenantId,
    required List<OwnerCashTransitSettlement> settlements,
  }) async {
    if (settlements.isEmpty) return settlements;
    final ids = settlements
        .map((s) => s.reservationId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return settlements;

    try {
      final safeRes = SupabaseService.safeFrom('reservations', tenantId);
      // Vylepšení UX: Přidání jména hosta k datům pobytu pro lepší orientaci majitele.
      final rows = await safeRes
          .select('id, guest_name, start_date, end_date')
          .inFilter('id', ids)
          .isFilter('deleted_at', null);

      final byId =
          <String, ({DateTime? start, DateTime? end, String? guestName})>{};
      for (final raw in (rows is List ? rows : const <dynamic>[])) {
        if (raw is! Map) continue;
        final id = raw['id']?.toString().trim();
        if (id == null || id.isEmpty) continue;
        final guestRaw = raw['guest_name']?.toString().trim();
        byId[id] = (
          start: _parseReservationDate(raw['start_date']),
          end: _parseReservationDate(raw['end_date']),
          guestName:
              guestRaw != null && guestRaw.isNotEmpty ? guestRaw : null,
        );
      }

      return settlements.map((s) {
        final rid = s.reservationId?.trim();
        if (rid == null || rid.isEmpty) return s;
        final pair = byId[rid];
        if (pair == null) return s;
        return s.copyWith(
          reservationStayStart: pair.start ?? s.reservationStayStart,
          reservationStayEnd: pair.end ?? s.reservationStayEnd,
          guestName: pair.guestName ?? s.guestName,
        );
      }).toList();
    } catch (e, st) {
      debugPrint('ReservationCashTransitRepository._mergeReservationStayDates: $e');
      debugPrint('$st');
      return settlements;
    }
  }

  /// Dostupný zůstatek majitele: (součet settlementů v měně) − (součet nevyčerpaných schválených žádostí).
  ///
  /// PROČ: Schválení žádosti na 250 EUR nesmí odečíst celých 666 EUR z jednoho settlementu.
  /// Rezervace = `amount - used_amount` u žádostí ve stavu approved / partially_completed / ready_for_pickup.
  static Future<double> getAvailableBalanceForOwner({
    required String tenantId,
    required String ownerProfileId,
    String currencyCode = 'EUR',
  }) async {
    final settlements = await listSettlementsForOwnerProfile(
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
    );
    final targetCur = currencyCode.trim().toUpperCase();
    final pool = _sumSettlementPoolAmount(
      settlements: settlements,
      targetCurrency: targetCur,
    );
    final reservedBySettlement = await _reservedAmountBySettlementId(
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
    );
    final reserved = _sumTotalReservedDispositionAmount(reservedBySettlement);
    final balance = math.max(0.0, pool - reserved);

    if (kDebugMode) {
      AppLogger.debug(
        'OwnerBalanceDebug[getAvailableBalanceForOwner] pool=$pool reserved=$reserved '
        'balance=$balance $targetCur (pool - sum(amount-used_amount) žádostí)',
      );
    }
    _debugLogOwnerBalancePipeline(
      phase: 'getAvailableBalanceForOwner',
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
      settlements: settlements,
      extra: {
        'currencyCode': currencyCode,
        'settlementPool': pool,
        'dispositionReserved': reserved,
        'displayedBalance': balance,
        'sumFormula': 'sum(settlements.amount) - sum(request.amount - request.used_amount)',
      },
    );
    return balance;
  }

  /// Fyzický pool majitele – součet všech settlementů v měně (včetně záporných zápočtů).
  ///
  /// PROČ: Validace zápočtu faktury musí kontrolovat reálný zůstatek v poolu, ne „volný“
  /// zůstatek po odečtu rezervací ze schválených žádostí (ta rezervace se uvolní až při čerpání).
  static Future<double> getOwnerSettlementPool({
    required String tenantId,
    required String ownerProfileId,
    String currencyCode = 'EUR',
  }) async {
    final settlements = await listSettlementsForOwnerProfile(
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
    );
    return _sumSettlementPoolAmount(
      settlements: settlements,
      targetCurrency: currencyCode,
    );
  }

  static Future<ReservationCashTransitSnapshot> resolve({
    required String tenantId,
    required String reservationId,
  }) async {
    final rid = reservationId.trim();
    final tid = tenantId.trim();
    if (rid.isEmpty || tid.isEmpty) {
      return const ReservationCashTransitSnapshot(
        phase: ReservationCashTransitPhase.notApplicable,
      );
    }

    final safeTasks = SupabaseService.safeFrom('tasks', tid);
    final safeTx = SupabaseService.safeFrom('employee_cash_transactions', tid);

    final taskRows = await safeTasks
        .select('id, metadata')
        .eq('reservation_id', rid)
        .isFilter('deleted_at', null);

    final tasks = (taskRows is List) ? taskRows : <dynamic>[];
    double? plannedMax;
    final taskIds = <String>[];
    final taskMetaById = <String, Map<String, dynamic>>{};
    for (final row in tasks) {
      if (row is! Map) continue;
      final id = row['id']?.toString();
      if (id != null && id.isNotEmpty) taskIds.add(id);
      final meta = row['metadata'];
      Map<String, dynamic>? m;
      if (meta is Map<String, dynamic>) {
        m = meta;
      } else if (meta is Map) {
        m = Map<String, dynamic>.from(meta);
      }
      if (id != null && id.isNotEmpty && m != null) {
        taskMetaById[id] = m;
      }
      final p = _transitAmountToCollectFromMetadata(m);
      if (p != null && (plannedMax == null || p > plannedMax)) plannedMax = p;
    }

    final settlementList = await fetchSettlementsForReservation(
      tenantId: tid,
      reservationId: rid,
    );
    if (settlementList.isNotEmpty) {
      final first = settlementList.first;
      return ReservationCashTransitSnapshot(
        phase: ReservationCashTransitPhase.settledToOwner,
        plannedAmount: plannedMax,
        currencyCode: first.currency.trim().isNotEmpty
            ? first.currency.trim()
            : 'EUR',
        collectedTotal: null,
        settledAmount: first.amount,
        settledAt: first.settledAt,
      );
    }

    var orFilter = 'reservation_id.eq.$rid';
    if (taskIds.isNotEmpty) {
      orFilter += ',task_id.in.(${taskIds.join(',')})';
    }

    final txRows = await safeTx
        .select(
          'transaction_type, amount, reservation_id, transit_portion, task_id',
        )
        .or(orFilter)
        .order('created_at', ascending: true);

    final list = (txRows is List) ? txRows : <dynamic>[];

    var collectedTotal = 0.0;
    var hasCollected = false;
    var hasHandedForReservation = false;

    for (final row in list) {
      if (row is! Map) continue;
      final type = (row['transaction_type'] as String?)?.trim() ?? '';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final resId = row['reservation_id']?.toString();

      if (type == 'COLLECTED_FROM_GUEST' && amount > 0) {
        final portion = _collectedTransitPortion(
          txRow: Map<String, dynamic>.from(row),
          taskMetaById: taskMetaById,
        );
        if (portion > 0) {
          hasCollected = true;
          collectedTotal += portion;
        }
      }
      if (type == 'HANDED_TO_AGENCY' && resId != null && resId == rid) {
        hasHandedForReservation = true;
      }
    }

    if (hasHandedForReservation) {
      return ReservationCashTransitSnapshot(
        phase: ReservationCashTransitPhase.atAgencyVault,
        plannedAmount: plannedMax,
        collectedTotal: hasCollected ? collectedTotal : null,
      );
    }

    if (hasCollected) {
      return ReservationCashTransitSnapshot(
        phase: ReservationCashTransitPhase.withWorker,
        plannedAmount: plannedMax,
        collectedTotal: collectedTotal,
      );
    }

    if (plannedMax != null) {
      return ReservationCashTransitSnapshot(
        phase: ReservationCashTransitPhase.awaitingCollection,
        plannedAmount: plannedMax,
      );
    }

    return const ReservationCashTransitSnapshot(
      phase: ReservationCashTransitPhase.notApplicable,
    );
  }

  /// Součet průtokové části majitele z výběrů od hosta (`COLLECTED_FROM_GUEST`) pro danou rezervaci.
  ///
  /// PROČ: Stejná logika jako u [resolve] – dopočet `transit_portion` z metadat úkolů (`transit_amount_to_collect`).
  static Future<double> ownerTransitCollectedTotalForReservation({
    required String tenantId,
    required String reservationId,
  }) async {
    final rid = reservationId.trim();
    final tid = tenantId.trim();
    if (rid.isEmpty || tid.isEmpty) return 0;

    final safeTasks = SupabaseService.safeFrom('tasks', tid);
    final safeTx = SupabaseService.safeFrom('employee_cash_transactions', tid);

    final taskRows = await safeTasks
        .select('id, metadata')
        .eq('reservation_id', rid)
        .isFilter('deleted_at', null);

    final tasks = (taskRows is List) ? taskRows : <dynamic>[];
    final taskIds = <String>[];
    final taskMetaById = <String, Map<String, dynamic>>{};
    for (final row in tasks) {
      if (row is! Map) continue;
      final id = row['id']?.toString();
      if (id != null && id.isNotEmpty) taskIds.add(id);
      final meta = row['metadata'];
      Map<String, dynamic>? m;
      if (meta is Map<String, dynamic>) {
        m = meta;
      } else if (meta is Map) {
        m = Map<String, dynamic>.from(meta);
      }
      if (id != null && id.isNotEmpty && m != null) {
        taskMetaById[id] = m;
      }
    }

    var orFilter = 'reservation_id.eq.$rid';
    if (taskIds.isNotEmpty) {
      orFilter += ',task_id.in.(${taskIds.join(',')})';
    }

    final txRows = await safeTx
        .select(
          'transaction_type, amount, reservation_id, transit_portion, task_id',
        )
        .or(orFilter)
        .order('created_at', ascending: true);

    final list = (txRows is List) ? txRows : <dynamic>[];
    var collectedTotal = 0.0;
    for (final row in list) {
      if (row is! Map) continue;
      final type = (row['transaction_type'] as String?)?.trim() ?? '';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      if (type == 'COLLECTED_FROM_GUEST' && amount > 0) {
        collectedTotal += _collectedTransitPortion(
          txRow: Map<String, dynamic>.from(row),
          taskMetaById: taskMetaById,
        );
      }
    }
    // DOČASNÝ DEBUG (požadavek incidentu): ověření dopočtu transit části majitele pro rezervaci.
    // ignore: avoid_print
    print('Nalezená průtoková částka: $collectedTotal');
    return collectedTotal;
  }

  /// Po převzetí hotovosti v trezoru (`HANDED_TO_AGENCY`) doplní řádek v `owner_cash_transit_settlements`
  /// pro část náležející majiteli (až do výše [handedAmountPositive] a zbývajícího plánu).
  ///
  /// PROČ: Dříve vznikla jen transakce v peněžence; klientský portál čte zůstatek ze settlementů a bez řádku
  /// padal nebo vracel chybu. Volá se až po úspěšném INSERTu HANDED. Vazba na transakci pokladny se ukládá
  /// do textového sloupce [note] (DB nemusí mít `employee_cash_transaction_id`).
  ///
  /// Částečné výběry: povoluje více settlement řádků na jednu rezervaci (součet nesmí překročit „nasbíraný“ podíl).
  static Future<bool> syncOwnerSettlementAfterHandedToAgency({
    required String tenantId,
    String? reservationId,
    String? sourceTaskId,
    required String adminProfileId,
    required String workerProfileId,
    required double handedAmountPositive,
    required String handedTransactionId,
  }) async {
    final tid = tenantId.trim();
    final rid = reservationId?.trim();
    final taskId = sourceTaskId?.trim();
    final pid = adminProfileId.trim();
    final wid = workerProfileId.trim();
    final txId = handedTransactionId.trim();
    if (tid.isEmpty || pid.isEmpty || txId.isEmpty) return true;
    if ((rid == null || rid.isEmpty) && (taskId == null || taskId.isEmpty)) {
      return true;
    }
    if (handedAmountPositive <= 0) return true;

    try {
      final safe = SupabaseService.safeFrom(
        'owner_cash_transit_settlements',
        tid,
      );

      Map<String, dynamic>? payloadData;
      if (rid != null && rid.isNotEmpty) {
        final collected = await ownerTransitCollectedTotalForReservation(
          tenantId: tid,
          reservationId: rid,
        );
        if (collected <= 1e-9) return true;

        final existing = await fetchSettlementsForReservation(
          tenantId: tid,
          reservationId: rid,
        );
        final alreadySettled = existing.fold<double>(0, (a, s) => a + s.amount);
        final remaining = math.max(0.0, collected - alreadySettled);
        if (remaining <= 1e-9) return true;

        final credit = math.min(remaining, handedAmountPositive);
        if (credit <= 1e-9) return true;

        final cur =
            existing.isNotEmpty && existing.first.currency.trim().isNotEmpty
            ? existing.first.currency.trim().toUpperCase()
            : 'EUR';
        payloadData = {
          'reservation_id': rid,
          'amount': credit,
          'currency': cur,
          'created_by': pid,
          'note': 'auto_handoff: HANDED_TO_AGENCY (tx: $txId)',
        };
      } else if (taskId != null && taskId.isNotEmpty) {
        final taskRow = await SupabaseService.safeFrom('tasks', tid)
            .select('id, apartment_id, reservation_id, metadata')
            .eq('id', taskId)
            .maybeSingle();
        if (taskRow == null) return true;
        final apartmentId = taskRow['apartment_id']?.toString().trim();
        if (apartmentId == null || apartmentId.isEmpty) return true;
        final reservationFromTask = taskRow['reservation_id']?.toString().trim();
        final metadataRaw = taskRow['metadata'];
        Map<String, dynamic>? taskMeta;
        if (metadataRaw is Map<String, dynamic>) {
          taskMeta = metadataRaw;
        } else if (metadataRaw is Map) {
          taskMeta = Map<String, dynamic>.from(metadataRaw);
        }
        final longTermDue = taskMeta?['long_term_rent_due'] == true;
        final plannedTransit = _transitAmountToCollectFromMetadata(taskMeta);

        var collectedForTask = 0.0;
        if (plannedTransit != null && plannedTransit > 0) {
          final txRows = await SupabaseService.safeFrom(
            'employee_cash_transactions',
            tid,
          )
              .select('transaction_type, amount, transit_portion, task_id')
              .eq('task_id', taskId)
              .order('created_at', ascending: true);
          for (final row in (txRows is List ? txRows : const <dynamic>[])) {
            if (row is! Map) continue;
            final type = (row['transaction_type'] as String?)?.trim() ?? '';
            final amount = (row['amount'] as num?)?.toDouble() ?? 0;
            if (type == 'COLLECTED_FROM_GUEST' && amount > 0) {
              collectedForTask += _collectedTransitPortion(
                txRow: Map<String, dynamic>.from(row),
                taskMetaById: {taskId: taskMeta ?? const <String, dynamic>{}},
              );
            }
          }
        }
        if (collectedForTask <= 1e-9) return true;

        final existingRows = await safe.select('amount').eq('task_id', taskId);
        final alreadySettled = (existingRows is List ? existingRows : const <dynamic>[])
            .whereType<Map>()
            .fold<double>(0.0, (sum, row) {
              final amount = row['amount'];
              final v = amount is num
                  ? amount.toDouble()
                  : double.tryParse(amount?.toString() ?? '');
              return sum + (v ?? 0.0);
            });
        final remaining = math.max(0.0, collectedForTask - alreadySettled);
        if (remaining <= 1e-9) return true;
        final credit = math.min(remaining, handedAmountPositive);
        if (credit <= 1e-9) return true;

        payloadData = {
          if (reservationFromTask != null && reservationFromTask.isNotEmpty)
            'reservation_id': reservationFromTask,
          'apartment_id': apartmentId,
          'task_id': taskId,
          'amount': credit,
          'currency': 'EUR',
          'created_by': pid,
          // PROČ: Na owner dashboardu potřebujeme jasně rozlišit settlementy z dlouhodobého nájmu.
          'note': longTermDue
              ? 'Vybrany najem (auto_handoff, tx: $txId)'
              : 'auto_handoff: HANDED_TO_AGENCY (task: $taskId, tx: $txId)',
        };
      }
      if (payloadData == null) return true;
      final payload = SupabaseService.safeInsertPayload(tid, payloadData);
      await safe.insert(payload);
      return true;
    } catch (e, st) {
      // PROČ: Selhání párování po HANDED nesmí zmizet „tiše“ – jinak vzniká černá díra v účetnictví.
      // Audit uchová vazbu na worker transakci i rezervaci pro ruční dohledání.
      try {
        await AuditLogService.log(
          tenantId: tid,
          userId: SupabaseService.client.auth.currentUser?.id,
          actionType: 'TRANSIT_SETTLEMENT_FAILED',
          tableName: 'owner_cash_transit_settlements',
          recordId: txId,
          details: {
            'employee_transaction_id': txId,
            'worker_id': wid,
            'reservation_id': rid,
            'task_id': taskId,
            'handed_amount': handedAmountPositive,
            'error': e.toString(),
            'stacktrace': st.toString(),
          },
        );
      } catch (auditErr, auditSt) {
        debugPrint(
          'ERROR: AuditLogService.log failed after TRANSIT_SETTLEMENT_FAILED: $auditErr',
        );
        debugPrint('ERROR: $auditSt');
      }
      return false;
    }
  }

  /// Zápis vyúčtování průtokové hotovosti majiteli. RLS: admin/manager (nebo super_admin).
  ///
  /// Vyhodí výjimku, pokud pro rezervaci už existuje záznam v `owner_cash_transit_settlements`.
  static Future<void> settleTransitCash({
    required String tenantId,
    required String reservationId,
    required String createdByProfileId,
    required double amount,
    String currency = 'EUR',
    String? note,
  }) async {
    final tid = tenantId.trim();
    final rid = reservationId.trim();
    final pid = createdByProfileId.trim();
    if (tid.isEmpty || rid.isEmpty || pid.isEmpty) {
      throw ArgumentError(
        'tenantId, reservationId and createdByProfileId must be non-empty',
      );
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be positive');
    }

    final safe = SupabaseService.safeFrom(
      'owner_cash_transit_settlements',
      tid,
    );
    final existing = await safe
        .select('id')
        .eq('reservation_id', rid)
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      throw StateError(
        'ReservationCashTransitRepository: reservation already has a transit settlement',
      );
    }

    final cur = currency.trim().toUpperCase();
    // PROČ: Stejné sloupce jako u `syncOwnerSettlementAfterHandedToAgency` – DB má `created_by` + `note`,
    // nikoli `settled_by` / `status` / `notes` (migrace `20260404120000`).
    final payload = SupabaseService.safeInsertPayload(tid, {
      'reservation_id': rid,
      'amount': amount,
      'currency': cur.isEmpty ? 'EUR' : cur,
      'created_by': pid,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    await safe.insert(payload);
  }
}
