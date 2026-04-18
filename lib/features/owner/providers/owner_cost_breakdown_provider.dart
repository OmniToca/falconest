import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/providers/owner_billing_provider.dart';
import 'package:falconest/features/owner/providers/owner_company_expenses_provider.dart';

/// Kategorie nákladů pro rozpad (pořadí = barvy v grafu zleva doprava v legendě).
///
/// PROČ: Oddělené enumy místo řetězců kvůli i18n klíčům v UI a stabilnímu mapování z `task_type`.
enum OwnerCostBucketType {
  cleaning,
  maintenance,
  management,
  otherServices,
  pendingUninvoiced,
}

/// Jedna „porce“ koláče – částka v měně tenanta (bez formátování).
class OwnerCostBreakdownSlice {
  const OwnerCostBreakdownSlice({required this.bucket, required this.amount});

  final OwnerCostBucketType bucket;
  final double amount;
}

/// Agregovaný rozpad nákladů majitele za referenční období.
///
/// PROČ: Jeden typ pro [ownerCostBreakdownProvider] i pro widget; [referenceMonth] je vždy
/// začátek kalendářního měsíce z **posledního** `billing_snapshots.billing_period` (zmražené vyúčtování).
class OwnerCostBreakdownData {
  const OwnerCostBreakdownData({
    required this.slices,
    required this.total,
    required this.referenceMonth,
  });

  final List<OwnerCostBreakdownSlice> slices;
  final double total;
  final DateTime? referenceMonth;
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

OwnerCostBucketType _bucketForTaskType(String? taskType) {
  if (taskType == null || taskType.trim().isEmpty) {
    return OwnerCostBucketType.otherServices;
  }
  final t = taskType.toLowerCase().trim();
  if (t == 'cleaning' || t.contains('cleaning') || t.contains('úklid') || t.contains('uklid')) {
    return OwnerCostBucketType.cleaning;
  }
  if (t == 'maintenance' ||
      t.contains('údržba') ||
      t.contains('udrzba') ||
      t == 'issue' ||
      t.contains('material') ||
      t.contains('oprav')) {
    return OwnerCostBucketType.maintenance;
  }
  if (t.contains('transfer') || t.contains('check_in') || t.contains('check_out')) {
    return OwnerCostBucketType.otherServices;
  }
  return OwnerCostBucketType.otherServices;
}

Future<Map<String, String>> _fetchTaskApartmentMap(Set<String> taskIds) async {
  if (taskIds.isEmpty) return {};
  const chunkSize = 100;
  final list = taskIds.toList();
  final out = <String, String>{};
  for (var i = 0; i < list.length; i += chunkSize) {
    final end = math.min(i + chunkSize, list.length);
    final chunk = list.sublist(i, end);
    final res = await SupabaseService.client
        .from('tasks')
        .select('id, apartment_id')
        .inFilter('id', chunk)
        .isFilter('deleted_at', null);
    for (final row in res as List) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = (m['id'] as String?)?.trim() ?? '';
      final apt = (m['apartment_id'] as String?)?.trim();
      if (id.isNotEmpty && apt != null && apt.isNotEmpty) {
        out[id] = apt;
      }
    }
  }
  return out;
}

Future<Map<String, String>> _fetchTaskTypes(Set<String> taskIds) async {
  if (taskIds.isEmpty) return {};
  const chunkSize = 100;
  final list = taskIds.toList();
  final out = <String, String>{};
  for (var i = 0; i < list.length; i += chunkSize) {
    final end = math.min(i + chunkSize, list.length);
    final chunk = list.sublist(i, end);
    final res = await SupabaseService.client
        .from('tasks')
        .select('id, task_type')
        .inFilter('id', chunk)
        .isFilter('deleted_at', null);
    for (final row in res as List) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = (m['id'] as String?)?.trim() ?? '';
      final tt = (m['task_type'] as String?)?.trim() ?? '';
      if (id.isNotEmpty) out[id] = tt;
    }
  }
  return out;
}

Future<Map<String, double>> _fetchMonthlyFeesByApartment(List<String> apartmentIds) async {
  if (apartmentIds.isEmpty) return {};
  const chunkSize = 100;
  final out = <String, double>{};
  for (var i = 0; i < apartmentIds.length; i += chunkSize) {
    final end = math.min(i + chunkSize, apartmentIds.length);
    final chunk = apartmentIds.sublist(i, end);
    final res = await SupabaseService.client
        .from('apartments')
        .select('id, monthly_management_fee')
        .inFilter('id', chunk)
        .isFilter('deleted_at', null);
    for (final row in res as List) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = (m['id'] as String?)?.trim() ?? '';
      final fee = _toDouble(m['monthly_management_fee']) ?? 0.0;
      if (id.isNotEmpty && fee > 0) out[id] = fee;
    }
  }
  return out;
}

/// Rozdělí paušál ze snapshotu mezi byty majitele podle `monthly_management_fee` v DB.
double _allocateMonthlyManagementFee({
  required double totalSnapshotFee,
  required String apartmentId,
  required List<String> ownerApartmentIds,
  required Map<String, double> feeByApartment,
}) {
  if (totalSnapshotFee <= 0) return 0;
  var sumWeights = 0.0;
  var ourWeight = 0.0;
  for (final id in ownerApartmentIds) {
    final w = feeByApartment[id] ?? 0.0;
    if (w > 0) {
      sumWeights += w;
      if (id == apartmentId) ourWeight = w;
    }
  }
  if (sumWeights <= 0 || ourWeight <= 0) return 0;
  return totalSnapshotFee * (ourWeight / sumWeights);
}

/// Spočítá rozpad nákladů z posledního vyúčtovacího snapshotu + nevyúčtovaných COMPANY_EXPENSE.
///
/// PROČ: Snapshot nemusí obsahovat `task_type` u položek – typy dotáhnu z `tasks` po `task_id`.
/// Firemní výdaje ve snapshotu bereme jen s neprázdným `apartment_id` v JSON (jinak nelze přiřadit bytu).
Future<OwnerCostBreakdownData> computeOwnerCostBreakdown({
  required List<String> ownedApartmentIds,
  required List<BillingSnapshotModel> snapshots,
  required List<OwnerCompanyExpenseRow> uninvoicedCompanyExpenses,
}) async {
  final owned = ownedApartmentIds.where((id) => id.isNotEmpty).toSet();
  if (owned.isEmpty) {
    return const OwnerCostBreakdownData(
      slices: [],
      total: 0,
      referenceMonth: null,
    );
  }

  BillingSnapshotModel? latest;
  for (final s in snapshots) {
    if (latest == null || s.billingPeriod.isAfter(latest.billingPeriod)) {
      latest = s;
    }
  }

  final amounts = <OwnerCostBucketType, double>{
    OwnerCostBucketType.cleaning: 0,
    OwnerCostBucketType.maintenance: 0,
    OwnerCostBucketType.management: 0,
    OwnerCostBucketType.otherServices: 0,
    OwnerCostBucketType.pendingUninvoiced: 0,
  };

  if (latest != null) {
    final snap = latest;
    final taskIds = <String>{};
    final itemsRaw = snap.snapshotData['items'];
    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final tid = (m['task_id'] as String?)?.trim() ?? '';
        if (tid.isEmpty) continue;
        final payer = (m['payer_type'] as String?)?.trim().toLowerCase() ?? 'guest';
        if (payer != 'owner') continue;
        final price = _toDouble(m['charged_price']) ?? 0.0;
        if (price <= 0) continue;
        taskIds.add(tid);
      }
    }

    final taskToApt = await _fetchTaskApartmentMap(taskIds);
    final taskToType = await _fetchTaskTypes(taskIds);
    final feeByApartment = await _fetchMonthlyFeesByApartment(ownedApartmentIds);
    final ownerList = ownedApartmentIds.where(owned.contains).toList();

    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final tid = (m['task_id'] as String?)?.trim() ?? '';
        if (tid.isEmpty) continue;
        final payer = (m['payer_type'] as String?)?.trim().toLowerCase() ?? 'guest';
        if (payer != 'owner') continue;
        final apt = taskToApt[tid];
        if (apt == null || !owned.contains(apt)) continue;
        final price = _toDouble(m['charged_price']) ?? 0.0;
        if (price <= 0) continue;
        final bucket = _bucketForTaskType(taskToType[tid]);
        amounts[bucket] = (amounts[bucket] ?? 0) + price;
      }
    }

    final expensesRaw = snap.snapshotData['expenses'];
    if (expensesRaw is List) {
      for (final e in expensesRaw) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final apt = (m['apartment_id'] as String?)?.trim();
        if (apt == null || apt.isEmpty || !owned.contains(apt)) continue;
        final amount = _toDouble(m['amount']) ?? 0.0;
        if (amount <= 0) continue;
        amounts[OwnerCostBucketType.maintenance] =
            (amounts[OwnerCostBucketType.maintenance] ?? 0) + amount;
      }
    }

    final snapshotMonthlyFee = _toDouble(snap.snapshotData['monthly_management_fee']) ?? 0.0;
    if (snapshotMonthlyFee > 0) {
      for (final aptId in owned) {
        final share = _allocateMonthlyManagementFee(
          totalSnapshotFee: snapshotMonthlyFee,
          apartmentId: aptId,
          ownerApartmentIds: ownerList,
          feeByApartment: feeByApartment,
        );
        if (share > 0) {
          amounts[OwnerCostBucketType.management] =
              (amounts[OwnerCostBucketType.management] ?? 0) + share;
        }
      }
    }
  }

  for (final row in uninvoicedCompanyExpenses) {
    if (!owned.contains(row.apartmentId)) continue;
    if (row.amount <= 0) continue;
    amounts[OwnerCostBucketType.pendingUninvoiced] =
        (amounts[OwnerCostBucketType.pendingUninvoiced] ?? 0) + row.amount;
  }

  final slices = <OwnerCostBreakdownSlice>[];
  for (final e in OwnerCostBucketType.values) {
    final v = amounts[e] ?? 0;
    if (v > 0) {
      slices.add(OwnerCostBreakdownSlice(bucket: e, amount: v));
    }
  }

  final total = slices.fold<double>(0, (s, sl) => s + sl.amount);

  final refMonth = latest != null
      ? DateTime.utc(latest.billingPeriod.year, latest.billingPeriod.month, 1)
      : null;

  return OwnerCostBreakdownData(
    slices: slices,
    total: total,
    referenceMonth: refMonth,
  );
}

/// Rozpad nákladů majitele pro prémiový graf na nástěnce.
///
/// PROČ: Kombinuje [ownerBillingSnapshotsProvider] (uzamčené měsíce) a [ownerUninvoicedCompanyExpensesProvider];
/// bez změny DB schématu.
final ownerCostBreakdownProvider = FutureProvider<OwnerCostBreakdownData>((ref) async {
  final apartments = await ref.watch(ownerApartmentsProvider.future);
  final ownedIds = apartments.map((a) => a.id).where((id) => id.isNotEmpty).toList();
  if (ownedIds.isEmpty) {
    return const OwnerCostBreakdownData(
      slices: [],
      total: 0,
      referenceMonth: null,
    );
  }

  final snapshots = await ref.watch(ownerBillingSnapshotsProvider.future);
  final uninvoiced = await ref.watch(ownerUninvoicedCompanyExpensesProvider.future);

  return computeOwnerCostBreakdown(
    ownedApartmentIds: ownedIds,
    snapshots: snapshots,
    uninvoicedCompanyExpenses: uninvoiced,
  );
});
