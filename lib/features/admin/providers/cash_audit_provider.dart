import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Filtr anomálií v přehledu „Hlídač hotovosti“.
///
/// PROČ: Dispečink potřebuje rychle přepnout mezi kritickými problémy (missing/duplicate/mismatch)
/// a plným seznamem bez dalšího SQL endpointu.
enum CashAuditAnomalyFilter {
  all('all'),
  missingCash('missing_cash'),
  duplicateCash('duplicate_cash'),
  amountMismatch('amount_mismatch'),
  ok('ok');

  const CashAuditAnomalyFilter(this.apiValue);
  final String apiValue;
}

/// Řádek z SQL view `vw_cash_collection_audit` rozšířený o název úkolu a bytu.
///
/// PROČ: UI musí na jednom místě zobrazit auditní částky i lidský kontext (task/apartment),
/// aby účetní nemusel dohledávat UUID ve druhé obrazovce.
class CashAuditRow {
  const CashAuditRow({
    required this.taskId,
    required this.apartmentId,
    required this.taskTitle,
    required this.apartmentName,
    required this.scheduledStart,
    required this.expectedCash,
    required this.collectedCash,
    required this.collectedCount,
    required this.anomalyType,
  });

  final String taskId;
  final String apartmentId;
  final String taskTitle;
  final String apartmentName;
  final DateTime? scheduledStart;
  final double expectedCash;
  final double collectedCash;
  final int collectedCount;
  final String anomalyType;
}

/// Aktivní filtr přehledu „Hlídač hotovosti“.
final cashAuditAnomalyFilterProvider =
    StateProvider.autoDispose<CashAuditAnomalyFilter>(
      (ref) => CashAuditAnomalyFilter.all,
    );

/// Načtení řádků cash auditu z SQL view `vw_cash_collection_audit`.
///
/// Dotaz čte přes `select('*')`, protože kontextové sloupce (`task_title`, `scheduled_start`,
/// `apartment_name`) jsou již denormalizované přímo ve view.
final cashAuditRowsProvider =
    FutureProvider.autoDispose.family<List<CashAuditRow>, CashAuditAnomalyFilter>(
      (ref, filter) async {
        final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
        if (tenantId == null || tenantId.isEmpty) return [];

        try {
          var query = SupabaseService.safeFrom(
            'vw_cash_collection_audit',
            tenantId,
          ).select('*');

          if (filter != CashAuditAnomalyFilter.all) {
            query = query.eq('anomaly_type', filter.apiValue);
          }

          final raw = await query.order('anomaly_type').order('task_id');
          final list = raw is List ? raw : const <dynamic>[];
          final rows = <CashAuditRow>[];
          for (final item in list) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final taskId = (map['task_id'] ?? '').toString().trim();
            if (taskId.isEmpty) continue;

            final apartmentId = (map['apartment_id'] ?? '').toString().trim();
            final expectedCash = _toDouble(map['expected_cash']);
            final collectedCash = _toDouble(map['collected_cash']);
            final collectedCount = _toInt(map['collected_count']);
            final anomalyType = (map['anomaly_type'] ?? 'ok').toString().trim();
            final taskTitle =
                (map['task_title']?.toString().trim() ?? '').isNotEmpty
                ? map['task_title'].toString().trim()
                : taskId;
            final apartmentName =
                (map['apartment_name']?.toString().trim() ?? '').isNotEmpty
                ? map['apartment_name'].toString().trim()
                : apartmentId;
            final scheduledStart = _parseDateTime(map['scheduled_start']);

            rows.add(
              CashAuditRow(
                taskId: taskId,
                apartmentId: apartmentId,
                taskTitle: taskTitle,
                apartmentName: apartmentName,
                scheduledStart: scheduledStart,
                expectedCash: expectedCash,
                collectedCash: collectedCash,
                collectedCount: collectedCount,
                anomalyType: anomalyType,
              ),
            );
          }

          rows.sort((a, b) {
            final ad = a.scheduledStart;
            final bd = b.scheduledStart;
            if (ad == null && bd == null) return 0;
            if (ad == null) return 1;
            if (bd == null) return -1;
            return bd.compareTo(ad);
          });
          return rows;
        } catch (e, st) {
          debugPrint(
            'cashAuditRowsProvider ERROR filter=${filter.apiValue} tenant=$tenantId error=$e',
          );
          AppLogger.error(
            'cashAuditRowsProvider: načtení vw_cash_collection_audit selhalo',
            e,
            st,
          );
          return [];
        }
      },
    );

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return 0;
  return double.tryParse(value.toString()) ?? 0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return 0;
  return int.tryParse(value.toString()) ?? 0;
}

DateTime? _parseDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

