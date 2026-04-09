import 'dart:math' as math;

import 'package:falconest/core/services/supabase_service.dart';

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
class ReservationCashTransitRepository {
  ReservationCashTransitRepository._();

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
  static double? _transitAmountToCollectFromMetadata(Map<String, dynamic>? meta) {
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
      final e = (explicit is num) ? explicit.toDouble() : double.tryParse(explicit.toString()) ?? 0;
      return e > 0 ? e : 0;
    }

    final taskId = txRow['task_id']?.toString();
    final meta = (taskId != null && taskId.isNotEmpty) ? taskMetaById[taskId] : null;
    final tPlan = _transitAmountToCollectFromMetadata(meta);
    final aPlan = _amountToCollectFromMetadata(meta);
    final hasTransitKey = meta?.containsKey('transit_amount_to_collect') ?? false;

    if (tPlan != null && tPlan > 0) {
      final agency = aPlan ?? 0;
      final afterAgency = math.max(0.0, amount - agency);
      final cap = math.min(afterAgency, tPlan);
      return cap > 0 ? cap : 0;
    }

    // Zpětná kompatibilita: úkol má jen `amount_to_collect` (smíšený bucket před rozdělením).
    if (!hasTransitKey && (aPlan != null && aPlan > 0)) {
      return amount;
    }
    return 0;
  }

  static Future<ReservationCashTransitSnapshot> resolve({
    required String tenantId,
    required String reservationId,
  }) async {
    final rid = reservationId.trim();
    final tid = tenantId.trim();
    if (rid.isEmpty || tid.isEmpty) {
      return const ReservationCashTransitSnapshot(phase: ReservationCashTransitPhase.notApplicable);
    }

    final safeTasks = SupabaseService.safeFrom('tasks', tid);
    final safeTx = SupabaseService.safeFrom('employee_cash_transactions', tid);
    final safeSettlements = SupabaseService.safeFrom('owner_cash_transit_settlements', tid);

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

    final settlementRes = await safeSettlements
        .select('amount, currency, settled_at')
        .eq('reservation_id', rid)
        .limit(1)
        .maybeSingle();

    if (settlementRes != null) {
      final m = Map<String, dynamic>.from(settlementRes);
      final amt = (m['amount'] as num?)?.toDouble();
      DateTime? settledAt;
      final rawAt = m['settled_at'];
      if (rawAt is String) settledAt = DateTime.tryParse(rawAt)?.toUtc();
      final cur = m['currency']?.toString().trim();
      return ReservationCashTransitSnapshot(
        phase: ReservationCashTransitPhase.settledToOwner,
        plannedAmount: plannedMax,
        currencyCode: (cur != null && cur.isNotEmpty) ? cur : 'EUR',
        collectedTotal: null,
        settledAmount: amt,
        settledAt: settledAt,
      );
    }

    var orFilter = 'reservation_id.eq.$rid';
    if (taskIds.isNotEmpty) {
      orFilter += ',task_id.in.(${taskIds.join(',')})';
    }

    final txRows = await safeTx
        .select('transaction_type, amount, reservation_id, transit_portion, task_id')
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
      if (type == 'HANDED_TO_AGENCY' &&
          resId != null &&
          resId == rid) {
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

    return const ReservationCashTransitSnapshot(phase: ReservationCashTransitPhase.notApplicable);
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
      throw ArgumentError('tenantId, reservationId and createdByProfileId must be non-empty');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be positive');
    }

    final safe = SupabaseService.safeFrom('owner_cash_transit_settlements', tid);
    final existing = await safe.select('id').eq('reservation_id', rid).limit(1).maybeSingle();
    if (existing != null) {
      throw StateError('ReservationCashTransitRepository: reservation already has a transit settlement');
    }

    final cur = currency.trim().toUpperCase();
    await safe.insert({
      'reservation_id': rid,
      'amount': amount,
      'currency': cur.isEmpty ? 'EUR' : cur,
      'created_by': pid,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }
}
