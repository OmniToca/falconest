import 'dart:math' as math;

import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
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

  /// Parsování řádků settlementů; poškozený řádek přeskočíme, aby majitelův dashboard nespadl na jedné chybě JSON.
  static List<OwnerCashTransitSettlement> _parseSettlementRows(dynamic rows) {
    final list = rows is List ? rows : const <dynamic>[];
    final out = <OwnerCashTransitSettlement>[];
    for (final e in list) {
      if (e is! Map) continue;
      try {
        out.add(
          OwnerCashTransitSettlement.fromJson(
            _normalizeSettlementJson(Map<String, dynamic>.from(e)),
          ),
        );
      } catch (e, st) {
        // PROČ: Supabase může vrátit neočekávaný tvar; raději vynechat řádek než shodit celý provider.
        debugPrint('Chyba při čtení settlementu: $e');
        debugPrint('$st');
      }
    }
    return out;
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
    if (aptIds.isEmpty) return [];

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
    if (resIds.isEmpty) {
      rows = await safeSettlements
          .select()
          .inFilter('apartment_id', aptIds)
          .order('settled_at', ascending: false);
    } else {
      final resCsv = resIds.join(',');
      final aptCsv = aptIds.join(',');
      // PROČ: Nové settlementy z dlouhodobého nájmu mohou mít `reservation_id=NULL`, proto musíme
      // vracet jak větev přes rezervaci, tak větev přes přímý `apartment_id`.
      rows = await safeSettlements
          .select()
          .or('reservation_id.in.($resCsv),apartment_id.in.($aptCsv)')
          .order('settled_at', ascending: false);
    }
    return _parseSettlementRows(rows);
  }

  /// Settlementy majitele s „volnou“ částkou v dané měně (stejná logika jako [getAvailableBalanceForOwner]).
  ///
  /// PROČ: UI potřebuje vybrat konkrétní [settlement_id] pro žádost o dispozici; součet zůstatku z těchto řádků.
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
    final ids = settlements.map((s) => s.id).toList();

    final safeDisp = SupabaseService.safeFrom(
      'owner_cash_disposition_requests',
      tenantId,
    );
    final dispRows = await safeDisp
        .select('settlement_id, status')
        .inFilter('settlement_id', ids)
        .inFilter('status', [
          'approved',
          'completed',
          'partially_completed',
          'ready_for_pickup',
        ]);

    final lockedSettlementIds = <String>{};
    for (final r in (dispRows is List ? dispRows : const <dynamic>[])) {
      if (r is! Map) continue;
      final sid = r['settlement_id']?.toString();
      if (sid != null && sid.isNotEmpty) lockedSettlementIds.add(sid);
    }

    final filtered = settlements.where((s) {
      if (s.currency.trim().toUpperCase() != targetCur) return false;
      if (s.status == 'fully_disbursed') return false;
      if (lockedSettlementIds.contains(s.id)) return false;
      return true;
    }).toList();

    return _mergeReservationStayDates(
      tenantId: tenantId,
      settlements: filtered,
    );
  }

  /// Doplní [OwnerCashTransitSettlement.reservationStayStart] / [reservationStayEnd] z tabulky reservations.
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
      final rows = await safeRes
          .select('id, start_date, end_date')
          .inFilter('id', ids)
          .isFilter('deleted_at', null);

      DateTime? parseDate(dynamic v) {
        if (v == null) return null;
        if (v is DateTime) return v;
        final s = v.toString().trim();
        if (s.isEmpty) return null;
        return DateTime.tryParse(s);
      }

      final byId = <String, ({DateTime? start, DateTime? end})>{};
      for (final raw in (rows is List ? rows : const <dynamic>[])) {
        if (raw is! Map) continue;
        final id = raw['id']?.toString().trim();
        if (id == null || id.isEmpty) continue;
        byId[id] = (
          start: parseDate(raw['start_date']),
          end: parseDate(raw['end_date']),
        );
      }

      return settlements.map((s) {
        final rid = s.reservationId?.trim();
        if (rid == null || rid.isEmpty) return s;
        final pair = byId[rid];
        if (pair == null) return s;
        return s.copyWith(
          reservationStayStart: pair.start,
          reservationStayEnd: pair.end,
        );
      }).toList();
    } catch (e, st) {
      debugPrint('ReservationCashTransitRepository._mergeReservationStayDates: $e');
      debugPrint('$st');
      return settlements;
    }
  }

  /// Součet „volných“ peněz majitele v dané měně: vyloučí [fully_disbursed] a settlementy,
  /// u kterých už existuje „otevřená“ žádost (`approved`, `completed`, `partially_completed`, `ready_for_pickup`).
  static Future<double> getAvailableBalanceForOwner({
    required String tenantId,
    required String ownerProfileId,
    String currencyCode = 'EUR',
  }) async {
    final list = await listAvailableSettlementsForOwner(
      tenantId: tenantId,
      ownerProfileId: ownerProfileId,
      currencyCode: currencyCode,
    );
    return list.fold<double>(0, (a, s) => a + s.amount);
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
