import 'dart:math' as math;

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/owner/providers/owner_billing_provider.dart';

/// Výpočet agenturních nákladů z uzamčených fakturačních snapshotů pro jeden apartmán.
///
/// PROČ: Snapshot je vždy za celého klienta (majitele); v `snapshot_data.items` chybí
/// `apartment_id`, proto po načtení `task_id` dávkujeme dotaz na `tasks` a sčítáme jen
/// řádky s `payer_type == owner` vázané na cílový byt. Měsíční paušál v JSON je součet
/// paušálů všech bytů klienta – přiřadíme podíl podle aktuálních vah z tabulky
/// `apartments.monthly_management_fee` (stejná logika jako při sestavování skupiny ve Finance).
class OwnerApartmentAgencyCostsFromSnapshots {
  OwnerApartmentAgencyCostsFromSnapshots._();

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime _firstOfMonthUtc(DateTime d) {
    final u = d.toUtc();
    return DateTime.utc(u.year, u.month, 1);
  }

  /// Pro [apartmentId] a [ownerApartmentIds] (všechny byty majitele v tenantovi) vrátí
  /// součty [agencyCosts] po měsících (`billing_period` snapshotu).
  static Future<Map<DateTime, double>> agencyCostsByMonth({
    required String apartmentId,
    required List<String> ownerApartmentIds,
    required List<BillingSnapshotModel> snapshots,
  }) async {
    if (apartmentId.isEmpty || snapshots.isEmpty) return {};

    final ownedSet = ownerApartmentIds.where((id) => id.isNotEmpty).toSet();
    if (!ownedSet.contains(apartmentId)) return {};

    final feeByApartment = await _fetchMonthlyFeesByApartment(ownedSet.toList());

    final taskIds = <String>{};
    for (final snap in snapshots) {
      final itemsRaw = snap.snapshotData['items'];
      if (itemsRaw is! List) continue;
      for (final item in itemsRaw) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final tid = (m['task_id'] as String?)?.trim() ?? '';
        if (tid.isEmpty) continue;
        final payer = (m['payer_type'] as String?)?.trim().toLowerCase() ?? 'guest';
        if (payer != 'owner') continue;
        taskIds.add(tid);
      }
    }

    final taskToApartment = await _fetchTaskApartmentMap(taskIds);

    final byMonth = <DateTime, double>{};

    for (final snap in snapshots) {
      final monthKey = _firstOfMonthUtc(snap.billingPeriod);
      var monthTotal = 0.0;

      final itemsRaw = snap.snapshotData['items'];
      if (itemsRaw is List) {
        for (final item in itemsRaw) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          final tid = (m['task_id'] as String?)?.trim() ?? '';
          if (tid.isEmpty) continue;
          final payer = (m['payer_type'] as String?)?.trim().toLowerCase() ?? 'guest';
          if (payer != 'owner') continue;
          final apt = taskToApartment[tid];
          if (apt == null || apt != apartmentId) continue;
          final price = _toDouble(m['charged_price']) ?? 0.0;
          if (price > 0) monthTotal += price;
        }
      }

      final expensesRaw = snap.snapshotData['expenses'];
      if (expensesRaw is List) {
        for (final e in expensesRaw) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final apt = (m['apartment_id'] as String?)?.trim();
          if (apt == null || apt != apartmentId) continue;
          final amount = _toDouble(m['amount']) ?? 0.0;
          if (amount > 0) monthTotal += amount;
        }
      }

      final snapshotMonthlyFee = _toDouble(snap.snapshotData['monthly_management_fee']) ?? 0.0;
      if (snapshotMonthlyFee > 0) {
        monthTotal += _allocateMonthlyManagementFee(
          totalSnapshotFee: snapshotMonthlyFee,
          apartmentId: apartmentId,
          ownerApartmentIds: ownedSet.toList(),
          feeByApartment: feeByApartment,
        );
      }

      if (monthTotal > 0) {
        byMonth[monthKey] = (byMonth[monthKey] ?? 0) + monthTotal;
      }
    }

    return byMonth;
  }

  /// Rozdělí celkový paušál ze snapshotu mezi byty majitele podle aktivních měsíčních poplatků v DB.
  static double _allocateMonthlyManagementFee({
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

  static Future<Map<String, double>> _fetchMonthlyFeesByApartment(List<String> apartmentIds) async {
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

  static Future<Map<String, String>> _fetchTaskApartmentMap(Set<String> taskIds) async {
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
}
