import 'package:falconest/core/models/apartment_investment_pnl_entry.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/owner/repositories/owner_apartment_pnl_repository.dart';

/// Metadata výběru nájmu za jeden kalendářní měsíc (pro sloupec Příjmy z nájmů).
class MonthlyRentPaymentMeta {
  const MonthlyRentPaymentMeta({
    this.rentPaidAt,
    this.rentBalanceDifference,
    this.plannedCollectionDate,
    this.actualCollectionDate,
    this.depositAmount,
    this.fifoAllocatedFromPool = 0,
    this.coveredFromPreviousPool = false,
  });

  /// Kdy byl nájem skutečně vybrán v hotovosti / potvrzen převodem (UTC) – pro bilanci.
  final DateTime? rentPaidAt;

  /// Bilance po FIFO amortizaci: alokovaná část z celkového poolu plateb − očekáváno měsíce.
  /// null = měsíc kauce – kauce nesmí sanovat dluh na nájmu.
  final double? rentBalanceDifference;

  /// Kauce z P&L – pouze zobrazení, mimo výpočet bilance nájmu.
  final double? depositAmount;

  /// Plánovaný termín výběru – [tasks.due_date] u úkolu rent_collection.
  final DateTime? plannedCollectionDate;

  /// Skutečné dokončení výběru – [tasks.completed_at] (nebo potvrzení převodu u notification).
  final DateTime? actualCollectionDate;

  /// Kolik EUR z globálního FIFO poolu bylo na tento měsíc alokováno (může být > fyzického výběru v měsíci).
  final double fifoAllocatedFromPool;

  /// True, pokud část úhrady šla z historických plateb / přeplatků, ne z výběru v tomto kalendářním měsíci.
  final bool coveredFromPreviousPool;
}

/// Souhrn úkolu rent_collection přiřazeného k jednomu měsíci P&L.
class _RentTaskTimeline {
  const _RentTaskTimeline({
    required this.taskIds,
    this.plannedCollectionDate,
    this.actualCollectionDate,
    this.isCompleted = false,
    this.expectedAmountToCollect,
  });

  final List<String> taskIds;
  final DateTime? plannedCollectionDate;
  final DateTime? actualCollectionDate;
  final bool isCompleted;

  /// Očekávaná částka z metadat úkolu (transit_amount_to_collect / rent_amount).
  final double? expectedAmountToCollect;

  _RentTaskTimeline merge(_RentTaskTimeline other) {
    final completed = isCompleted || other.isCompleted;
    DateTime? planned = plannedCollectionDate;
    if (other.plannedCollectionDate != null) {
      if (planned == null || other.plannedCollectionDate!.isBefore(planned)) {
        planned = other.plannedCollectionDate;
      }
    }
    DateTime? actual = actualCollectionDate;
    if (other.actualCollectionDate != null) {
      if (actual == null || other.actualCollectionDate!.isAfter(actual)) {
        actual = other.actualCollectionDate;
      }
    }
    double? expected = expectedAmountToCollect;
    if (other.expectedAmountToCollect != null) {
      if (expected == null || other.expectedAmountToCollect! > expected) {
        expected = other.expectedAmountToCollect;
      }
    }
    return _RentTaskTimeline(
      taskIds: [...taskIds, ...other.taskIds],
      plannedCollectionDate: planned,
      actualCollectionDate: actual,
      isCompleted: completed,
      expectedAmountToCollect: expected,
    );
  }
}

/// Vstup jednoho měsíce pro FIFO amortizaci (bez kauce).
class _FifoRentMonth {
  const _FifoRentMonth({
    required this.month,
    required this.expectedAmount,
    required this.paidAmountInMonth,
    required this.meta,
  });

  final DateTime month;
  final double expectedAmount;

  /// Skutečně přijaté peníze v daném kalendářním měsíci (cash-flow), mimo kauci.
  final double paidAmountInMonth;
  final MonthlyRentPaymentMeta meta;
}

/// Načtení data výběru a bilance nájmu z Supabase pro dlouhodobý pronájem.
///
/// PROČ: Tabulka P&L ukazuje jen souhrnný [apartment_investment_pnl_entries.income];
/// majitel potřebuje stav úhrady – čte se z dokončených úkolů [tasks] (rent_collection),
/// hotovostních transakcí [employee_cash_transactions] a případně potvrzení převodu v P&L.
class OwnerRentPaymentDetailsService {
  OwnerRentPaymentDetailsService._();

  static const String _txCollected = 'COLLECTED_FROM_GUEST';
  static const String _txReversal = 'CASH_COLLECTION_REVERSAL';
  static const String _statusCompleted = 'completed';

  /// Mapa první den měsíce (UTC) → metadata platby nájmu.
  static Future<Map<DateTime, MonthlyRentPaymentMeta>> loadByApartmentId({
    required String tenantId,
    required String apartmentId,
    /// Záložní očekávaný nájem z [apartments.rent_amount], pokud pro měsíc chybí úkol.
    required double apartmentRentAmountFallback,
    required List<ApartmentInvestmentPnlEntry> pnlEntries,
  }) async {
    if (apartmentId.isEmpty || tenantId.isEmpty) return {};

    try {
      // Načtení časové osy výběru nájmu z tabulky úkolů pro detailnější zobrazení v P&L.
      final safeTasks = SupabaseService.safeFrom('tasks', tenantId);
      final taskRows = await safeTasks
          .select('id, metadata, completed_at, updated_at, due_date, status')
          .eq('apartment_id', apartmentId)
          .eq('task_type', 'rent_collection')
          .isFilter('deleted_at', null);

      final monthToTimeline = <DateTime, _RentTaskTimeline>{};

      for (final raw in taskRows as List<dynamic>) {
        final map = Map<String, dynamic>.from(raw as Map);
        final taskId = map['id']?.toString() ?? '';
        if (taskId.isEmpty) continue;

        final meta = map['metadata'];
        final metaMap = meta is Map
            ? Map<String, dynamic>.from(meta)
            : (meta is Map<String, dynamic> ? meta : <String, dynamic>{});

        final month = _monthFromTaskMetadata(metaMap, apartmentId);
        if (month == null) continue;

        final status = (map['status']?.toString() ?? '').trim().toLowerCase();
        final isCompleted = status == _statusCompleted;
        final completedAt = isCompleted ? _parseDateTime(map['completed_at']) : null;
        final dueDate = _parseDateTime(map['due_date']);

        final slice = _RentTaskTimeline(
          taskIds: [taskId],
          plannedCollectionDate: dueDate,
          actualCollectionDate: completedAt,
          isCompleted: isCompleted,
          expectedAmountToCollect: _expectedAmountFromTaskMetadata(metaMap),
        );

        final prev = monthToTimeline[month];
        monthToTimeline[month] = prev == null ? slice : prev.merge(slice);
      }

      final allRentTaskIds = <String>{
        for (final tl in monthToTimeline.values) ...tl.taskIds,
      };

      final paidByTask = <String, double>{};
      final paidAtByTask = <String, DateTime>{};

      // PROČ: Výběr nájmu často nemá vyplněné apartment_id na transakci – párujeme přes task_id.
      if (allRentTaskIds.isNotEmpty) {
        final safeTx = SupabaseService.safeFrom('employee_cash_transactions', tenantId);
        final txRows = await safeTx
            .select('task_id, amount, transaction_type, created_at')
            .inFilter('task_id', allRentTaskIds.toList())
            .inFilter('transaction_type', [_txCollected, _txReversal]);

        for (final raw in txRows as List<dynamic>) {
          final map = Map<String, dynamic>.from(raw as Map);
          final taskId = map['task_id']?.toString() ?? '';
          if (taskId.isEmpty) continue;

          final type = (map['transaction_type']?.toString() ?? '').trim();
          final amount = _toDouble(map['amount']) ?? 0;
          if (amount <= 0) continue;

          if (type == _txCollected) {
            paidByTask[taskId] = (paidByTask[taskId] ?? 0) + amount;
            final at = _parseDateTime(map['created_at']);
            if (at != null) {
              final prev = paidAtByTask[taskId];
              if (prev == null || at.isAfter(prev)) {
                paidAtByTask[taskId] = at;
              }
            }
          } else if (type == _txReversal) {
            paidByTask[taskId] = (paidByTask[taskId] ?? 0) - amount;
          }
        }
      }

      final incomeByMonth = <DateTime, ApartmentInvestmentPnlEntry>{};
      for (final e in pnlEntries) {
        if (e.entryType != 'income') continue;
        final m = DateTime.utc(e.entryMonth.year, e.entryMonth.month, 1);
        incomeByMonth[m] = e;
      }

      final out = <DateTime, MonthlyRentPaymentMeta>{};
      final fifoMonths = <_FifoRentMonth>[];
      final monthKeys = <DateTime>{}
        ..addAll(monthToTimeline.keys)
        ..addAll(incomeByMonth.keys);

      for (final month in monthKeys) {
        final timeline = monthToTimeline[month];
        final taskIds = timeline?.taskIds ?? const [];
        final incomeEntry = incomeByMonth[month];
        final isDepositMonth =
            incomeEntry != null && _isDepositPnlDescription(incomeEntry.description);
        final isTransferConfirm = incomeEntry != null &&
            (incomeEntry.description ?? '').trim() ==
                OwnerApartmentPnlRepository.kDbDescriptionRentTransferConfirmed;

        var paidFromCash = 0.0;
        DateTime? paidAt;
        for (final tid in taskIds) {
          final net = paidByTask[tid] ?? 0;
          if (net > 0) {
            paidFromCash += net;
            final at = paidAtByTask[tid];
            if (at != null && (paidAt == null || at.isAfter(paidAt))) {
              paidAt = at;
            }
          }
        }

        // PROČ: Kauce v description nesmí vstoupit do paidAmount pro bilanci běžného nájmu.
        final paidFromPnl =
            isDepositMonth ? 0.0 : (incomeEntry?.amount ?? 0);

        // Oprava načítání skutečně vybrané částky pro výpočet bilance.
        // Primárně očištěná hotovost z úkolu; bez transakce P&L income (trigger / potvrzený převod).
        var paidAmount = isDepositMonth ? 0.0 : paidFromCash;
        if (!isDepositMonth && paidAmount <= 0 && paidFromPnl > 0) {
          paidAmount = paidFromPnl;
          paidAt ??= incomeEntry?.updatedAt ?? incomeEntry?.createdAt;
        }

        if (!isDepositMonth &&
            paidAmount <= 0 &&
            incomeEntry == null &&
            taskIds.isEmpty) {
          continue;
        }

        final expectedAmount = timeline?.expectedAmountToCollect ??
            (apartmentRentAmountFallback > 0 ? apartmentRentAmountFallback : null);

        DateTime? actualCollectionDate = timeline?.actualCollectionDate;
        if (actualCollectionDate == null && isTransferConfirm) {
          actualCollectionDate = incomeEntry!.updatedAt ?? incomeEntry.createdAt;
        }

        if (isDepositMonth) {
          out[month] = MonthlyRentPaymentMeta(
            rentPaidAt: paidAt,
            depositAmount: incomeEntry!.amount,
            plannedCollectionDate: timeline?.plannedCollectionDate,
            actualCollectionDate: actualCollectionDate,
          );
          continue;
        }

        if (paidAmount <= 0 && incomeEntry == null && expectedAmount == null) {
          continue;
        }

        final expected = expectedAmount ?? 0;
        final meta = MonthlyRentPaymentMeta(
          rentPaidAt: paidAt,
          plannedCollectionDate: timeline?.plannedCollectionDate,
          actualCollectionDate: actualCollectionDate,
        );

        out[month] = meta;
        fifoMonths.add(
          _FifoRentMonth(
            month: month,
            expectedAmount: expected,
            paidAmountInMonth: paidAmount,
            meta: meta,
          ),
        );
      }

      _applyFifoRentBalances(fifoMonths, out);

      return out;
    } catch (e, st) {
      AppLogger.error('OwnerRentPaymentDetailsService.loadByApartmentId', e, st);
      return {};
    }
  }

  /// FIFO Amortizační engine: Chronologické rozlévání celkových plateb od nejstaršího měsíce pro správné umořování dluhů.
  static void _applyFifoRentBalances(
    List<_FifoRentMonth> months,
    Map<DateTime, MonthlyRentPaymentMeta> out,
  ) {
    if (months.isEmpty) return;

    months.sort((a, b) => a.month.compareTo(b.month));

    var pool = 0.0;
    for (final m in months) {
      pool += m.paidAmountInMonth;
    }

    for (final m in months) {
      final expected = m.expectedAmount;
      double balanceDiff;
      var allocatedFromPool = 0.0;

      if (expected <= 0.009) {
        balanceDiff = 0;
      } else if (pool <= 0.009) {
        balanceDiff = -expected;
      } else if (pool >= expected - 0.009) {
        allocatedFromPool = expected;
        pool -= expected;
        balanceDiff = 0;
      } else {
        allocatedFromPool = pool;
        balanceDiff = pool - expected;
        pool = 0;
      }

      // Zobrazení informace, že dluh v tomto měsíci byl zalepen penězi z historických přeplatků.
      final coveredFromPrevious = allocatedFromPool > m.paidAmountInMonth + 0.009 &&
          allocatedFromPool > 0.009;

      out[m.month] = MonthlyRentPaymentMeta(
        rentPaidAt: m.meta.rentPaidAt,
        plannedCollectionDate: m.meta.plannedCollectionDate,
        actualCollectionDate: m.meta.actualCollectionDate,
        depositAmount: m.meta.depositAmount,
        rentBalanceDifference: balanceDiff,
        fifoAllocatedFromPool: allocatedFromPool,
        coveredFromPreviousPool: coveredFromPrevious,
      );
    }

    if (pool > 0.009) {
      final lastKey = months.last.month;
      final last = out[lastKey]!;
      out[lastKey] = MonthlyRentPaymentMeta(
        rentPaidAt: last.rentPaidAt,
        plannedCollectionDate: last.plannedCollectionDate,
        actualCollectionDate: last.actualCollectionDate,
        depositAmount: last.depositAmount,
        rentBalanceDifference: (last.rentBalanceDifference ?? 0) + pool,
        fifoAllocatedFromPool: last.fifoAllocatedFromPool,
        coveredFromPreviousPool: last.coveredFromPreviousPool,
      );
    }
  }

  /// Párování měsíce P&L s úkolem: primárně [metadata.rent_cycle_key], záložně [metadata.billing_month].
  static DateTime? _monthFromTaskMetadata(Map<String, dynamic> meta, String apartmentId) {
    final fromKey = _monthFromRentCycleKey(meta['rent_cycle_key']?.toString(), apartmentId);
    if (fromKey != null) return fromKey;

    final billingMonth = meta['billing_month']?.toString().trim();
    if (billingMonth == null || billingMonth.isEmpty) return null;
    try {
      final d = DateTime.parse(billingMonth);
      return DateTime.utc(d.year, d.month, 1);
    } catch (_) {
      return null;
    }
  }

  /// P&L příjem označený jako kauce – mimo bilanci nájmu (nesanuje dluhy).
  static bool _isDepositPnlDescription(String? description) {
    return (description ?? '').trim().toLowerCase().contains('kauce');
  }

  /// Získání dynamické částky k vybrání přímo z úkolu. Zohledňuje případné nedoplatky
  /// nebo extra poplatky zanesené do JSON metadat.
  static double? _expectedAmountFromTaskMetadata(Map<String, dynamic> meta) {
    final transit = _toDouble(meta['transit_amount_to_collect']);
    if (transit != null && transit > 0) return transit;

    final rent = _toDouble(meta['rent_amount']);
    if (rent != null && rent > 0) return rent;

    return null;
  }

  static DateTime? _monthFromRentCycleKey(String? key, String apartmentId) {
    if (key == null || key.trim().isEmpty) return null;
    final colon = key.indexOf(':');
    if (colon < 1) return null;
    final prefix = key.substring(0, colon).trim();
    if (prefix != apartmentId) return null;
    final datePart = key.substring(colon + 1).trim();
    try {
      final d = DateTime.parse(datePart);
      return DateTime.utc(d.year, d.month, 1);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toUtc();
  }

  static double? _toDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }
}
