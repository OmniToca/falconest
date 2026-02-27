import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/reservation_services_repository.dart';

/// Jeden dokončený úkol v podkladu pro fakturaci.
///
/// PROČ úkolová logika: Fakturujeme POUZE skutečně dokončené úkoly, ne rezervace.
/// Rezervace může být zrušena, úkol nemusel vzniknout nebo byl smazán – zdrojem pravdy
/// pro „co bylo fyzicky vykonáno“ je úkol se statusem completed. Sloupec invoiced_at
/// zajišťuje, že vyfakturované úkoly se již neukazují a neduplikují se.
class BillingTaskItem {
  const BillingTaskItem({
    required this.taskId,
    required this.title,
    required this.completedAt,
    required this.chargedPrice,
    required this.payerType,
    this.taskType,
  });

  final String taskId;
  final String title;
  final DateTime? completedAt;
  final double chargedPrice;
  /// 'owner' = k fakturaci majiteli, 'guest' = vybráno v hotovosti.
  final String payerType;
  final String? taskType;
}

/// Skupina úkolů pro jeden apartmán – agregace pro fakturaci.
///
/// PROČ seskupení po bytu: Majitelé vlastní byty; faktura se sestavuje per apartmán.
/// Každá karta zobrazuje seznam skutečně dokončených a nevyfakturovaných úkolů
/// s jejich cenami z reservation_services (přes service_id úkolu).
class BillingApartmentGroup {
  const BillingApartmentGroup({
    required this.apartmentId,
    required this.apartmentName,
    required this.tasks,
    required this.totalToInvoice,
    required this.totalCashCollected,
  });

  final String apartmentId;
  final String apartmentName;
  final List<BillingTaskItem> tasks;
  final double totalToInvoice;
  final double totalCashCollected;
}

/// Parametr pro billing report – měsíc a rok.
class BillingMonthParam {
  const BillingMonthParam({required this.year, required this.month});
  final int year;
  final int month;
}

/// Načte fakturační podklady na základě DOKONČENÝCH a NEVYFAKTUROVANÝCH ÚKOLŮ.
///
/// PROČ úkolová logika místo rezervací:
/// - Rezervace = záměr pobytu. Skutečnost = co pracovník reálně udělal (úkol completed).
/// - Rezervace mohla být zrušena, úklid mohl být přeřazen – fakturujeme jen to, co proběhlo.
/// - Sloupec invoiced_at zabraňuje duplicitnímu fakturování; po označení úkoly zmizí z přehledu.
///
/// Filtrace: status = 'completed', invoiced_at IS NULL, completed_at v zvoleném měsíci.
/// Ceny: Z reservation_services (charged_price, payer_type) – párování přes reservation_id a service_id.
final billingReportProvider =
    FutureProvider.family<List<BillingApartmentGroup>, BillingMonthParam>((ref, param) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final apartments = await ref.watch(apartmentsProvider.future);
  final apartmentById = {for (final a in apartments) a.id: a.name};
  if (apartments.isEmpty) return [];

  final startOfMonth = DateTime.utc(param.year, param.month, 1);
  final startOfNextMonth = DateTime.utc(param.year, param.month + 1, 1);

  try {
    // Krok 1: Načti dokončené nevyfakturované úkoly s completed_at v zvoleném měsíci.
    // PROČ: Fakturujeme pouze reálně vykonané úkoly; completed_at = kdy byl úkol dokončen.
    final tasksRes = await SupabaseService.client
        .from('tasks')
        .select('id, title, task_type, apartment_id, reservation_id, service_id, completed_at, due_date')
        .eq('tenant_id', tenantId)
        .eq('status', 'completed')
        .isFilter('deleted_at', null)
        .isFilter('invoiced_at', null);

    final tasksList = (tasksRes as List).cast<Map<String, dynamic>>();
    if (tasksList.isEmpty) return [];

    // Filtrace podle měsíce: preferuj completed_at, fallback due_date.
    final tasksInMonth = <Map<String, dynamic>>[];
    for (final t in tasksList) {
      final completedAt = _parseDateTime(t['completed_at']);
      final dueDate = _parseDateTime(t['due_date']);
      final refDate = completedAt ?? dueDate;
      if (refDate == null) continue;
      final utc = refDate.toUtc();
      if (utc.isBefore(startOfMonth) || !utc.isBefore(startOfNextMonth)) continue;
      tasksInMonth.add(t);
    }
    if (tasksInMonth.isEmpty) return [];

    final reservationIds = tasksInMonth
        .map((t) => (t['reservation_id'] as String?)?.trim())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    if (reservationIds.isEmpty) return [];

    // Krok 2: Načti reservation_services pro tyto rezervace.
    final servicesByRes = await fetchByReservationIds(reservationIds, tenantId);

    // Krok 3: Mapování apartment_service_id -> service_id (pro párování úkol-service).
    final apartmentServiceIds = <String>{};
    for (final list in servicesByRes.values) {
      for (final rs in list) {
        final id = rs.apartmentServiceId.trim();
        if (id.isNotEmpty) apartmentServiceIds.add(id);
      }
    }
    final aptServiceToServiceId = <String, String>{};
    if (apartmentServiceIds.isNotEmpty) {
      // SECURITY FIX: Explicitní defense-in-depth kontrola na tenant_id.
      final aptRes = await SupabaseService.client
          .from('apartment_services')
          .select('id, service_id')
          .eq('tenant_id', tenantId)
          .inFilter('id', apartmentServiceIds.toList());
      for (final row in (aptRes as List)) {
        final m = row as Map<String, dynamic>;
        final id = (m['id'] as String?)?.trim();
        final sid = (m['service_id'] as String?)?.trim();
        if (id != null && id.isNotEmpty && sid != null && sid.isNotEmpty) {
          aptServiceToServiceId[id] = sid;
        }
      }
    }

    // Krok 4: Sestav (reservation_id, service_id) -> (charged_price, payer_type).
    final priceByResService = <String, ({double price, String payerType})>{};
    for (final entry in servicesByRes.entries) {
      for (final rs in entry.value) {
        final sid = aptServiceToServiceId[rs.apartmentServiceId];
        if (sid == null) continue;
        final key = '${entry.key}|$sid';
        final price = (rs.chargedPrice ?? 0).toDouble();
        final pt = (rs.payerType ?? 'guest').trim();
        priceByResService[key] = (price: price, payerType: pt);
      }
    }

    // Krok 5: Pro každý úkol vytvoř BillingTaskItem a seskupte po apartmánu.
    final byApartment = <String, List<BillingTaskItem>>{};
    for (final t in tasksInMonth) {
      final resId = (t['reservation_id'] as String?)?.trim() ?? '';
      final svcId = (t['service_id'] as String?)?.trim() ?? '';
      final aptId = (t['apartment_id'] as String?)?.trim() ?? '';
      if (aptId.isEmpty) continue;

      final key = '$resId|$svcId';
      final priceData = priceByResService[key];
      final chargedPrice = priceData?.price ?? 0.0;
      final payerType = priceData?.payerType ?? 'guest';

      final item = BillingTaskItem(
        taskId: (t['id'] as String?)?.trim() ?? '',
        title: (t['title'] as String?)?.trim() ?? '',
        completedAt: _parseDateTime(t['completed_at']),
        chargedPrice: chargedPrice,
        payerType: payerType,
        taskType: (t['task_type'] as String?)?.trim(),
      );
      byApartment.putIfAbsent(aptId, () => []).add(item);
    }

    // Krok 6: Agregace na BillingApartmentGroup.
    final groups = <BillingApartmentGroup>[];
    for (final entry in byApartment.entries) {
      final aptId = entry.key;
      final items = entry.value;
      double toInvoice = 0;
      double cash = 0;
      for (final it in items) {
        if (it.payerType == 'owner') {
          toInvoice += it.chargedPrice;
        } else {
          cash += it.chargedPrice;
        }
      }
      groups.add(BillingApartmentGroup(
        apartmentId: aptId,
        apartmentName: apartmentById[aptId] ?? aptId,
        tasks: items,
        totalToInvoice: toInvoice,
        totalCashCollected: cash,
      ));
    }
    groups.sort((a, b) => a.apartmentName.compareTo(b.apartmentName));
    return groups;
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Billing Error: $e');
      // ignore: avoid_print
      print(st);
    }
    rethrow;
  }
});

DateTime? _parseDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}
