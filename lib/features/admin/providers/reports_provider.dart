import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/reservation_services_repository.dart';

// =============================================================================
// MODELY PRO AGREGACI REPORTŮ
// =============================================================================

/// Výkonnost jednoho zaměstnance za vybraný měsíc.
///
/// [assigneeId] = profile.id (UUID) přiřazeného pracovníka. Prázdný řetězec = úkoly
/// bez přiřazení (agregace do „Nepřiřazeno“).
/// [taskCount] = počet dokončených úkolů, kde assigned_to == assigneeId.
/// [hoursWorked] = odpracované hodiny – součet z reálných časů (completed_at - started_at)
/// když oba existují, jinak fallback na metadata.estimated_minutes.
class EmployeePerformance {
  const EmployeePerformance({
    required this.assigneeId,
    required this.taskCount,
    required this.hoursWorked,
  });

  final String assigneeId;
  final int taskCount;
  /// Hodiny (desetinné), např. 12.5 = 12h 30min.
  final double hoursWorked;
}

/// Ziskovost jednoho apartmánu za vybraný měsíc.
///
/// [apartmentId] = UUID bytu.
/// [totalRevenue] = součet charged_price všech dokončených úkolů pro tento byt
/// (přes reservation_services – owner + guest dohromady jako celková tržba).
class ApartmentRevenue {
  const ApartmentRevenue({
    required this.apartmentId,
    required this.totalRevenue,
  });

  final String apartmentId;
  final double totalRevenue;
}

/// Obálka agregovaných dat pro modul Reporty.
class ReportsSummary {
  const ReportsSummary({
    required this.employeePerformances,
    required this.apartmentRevenues,
    required this.totalMonthRevenue,
    required this.month,
    required this.year,
  });

  final List<EmployeePerformance> employeePerformances;
  final List<ApartmentRevenue> apartmentRevenues;
  /// Celková tržba za měsíc (součet totalRevenue všech apartmánů).
  final double totalMonthRevenue;
  final int month;
  final int year;
}

// =============================================================================
// FILTR OBDOBÍ
// =============================================================================

/// Aktuálně prohlížený měsíc – výchozí je současnost.
/// UI může měnit hodnotu pro přepínání mezi měsíci.
final reportsMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

// =============================================================================
// HLAVNÍ PROVIDER
// =============================================================================

/// Načte agregovaná data pro Reporty na základě [reportsMonthProvider].
///
/// Logika shodná s finance_billing_provider pro ceny úkolů (reservation_services,
/// apartment_services, charged_price). Rozdíl: nefiltrujeme podle invoiced_at –
/// zahrnujeme VŠECHNY dokončené úkoly v měsíci (včetně již vyfakturovaných).
final reportsDataProvider = FutureProvider<ReportsSummary>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) {
    return ReportsSummary(
      employeePerformances: [],
      apartmentRevenues: [],
      totalMonthRevenue: 0,
      month: 0,
      year: 0,
    );
  }

  final selectedMonth = ref.watch(reportsMonthProvider);
  final year = selectedMonth.year;
  final month = selectedMonth.month;
  final startOfMonth = DateTime.utc(year, month, 1);
  final startOfNextMonth = DateTime.utc(year, month + 1, 1);

  try {
    // Krok 1: Načti VŠECHNY dokončené úkoly tenantu (bez filtru na invoiced_at).
    // PROČ: Reporty zobrazují celkovou výkonnost a ziskovost – včetně již vyfakturovaných.
    final tasksRes = await SupabaseService.client
        .from('tasks')
        .select(
          'id, title, task_type, apartment_id, reservation_id, service_id, '
          'completed_at, due_date, scheduled_start, assigned_to, started_at, metadata',
        )
        .eq('tenant_id', tenantId)
        .eq('status', 'completed')
        .isFilter('deleted_at', null);

    final tasksList = (tasksRes as List).cast<Map<String, dynamic>>();
    if (tasksList.isEmpty) {
      return ReportsSummary(
        employeePerformances: [],
        apartmentRevenues: [],
        totalMonthRevenue: 0,
        month: month,
        year: year,
      );
    }

    // Filtrace podle měsíce: preferuj completed_at, fallback due_date, scheduled_start.
    final tasksInMonth = <Map<String, dynamic>>[];
    for (final t in tasksList) {
      final refDate =
          _parseDateTime(t['completed_at']) ??
          _parseDateTime(t['due_date']) ??
          _parseDateTime(t['scheduled_start']);
      if (refDate == null) continue;
      final utc = refDate.toUtc();
      if (utc.isBefore(startOfMonth) || !utc.isBefore(startOfNextMonth)) continue;
      tasksInMonth.add(t);
    }
    if (tasksInMonth.isEmpty) {
      return ReportsSummary(
        employeePerformances: [],
        apartmentRevenues: [],
        totalMonthRevenue: 0,
        month: month,
        year: year,
      );
    }

    // Krok 2: Ceny z reservation_services (stejná logika jako finance_billing_provider).
    final reservationIds = tasksInMonth
        .map((t) => (t['reservation_id'] as String?)?.trim())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final priceByResService = <String, double>{};
    if (reservationIds.isNotEmpty) {
      final servicesByRes = await fetchByReservationIds(reservationIds, tenantId);
      final apartmentServiceIds = <String>{};
      for (final list in servicesByRes.values) {
        for (final rs in list) {
          final id = rs.apartmentServiceId.trim();
          if (id.isNotEmpty) apartmentServiceIds.add(id);
        }
      }
      final aptServiceToServiceId = <String, String>{};
      if (apartmentServiceIds.isNotEmpty) {
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
      for (final entry in servicesByRes.entries) {
        for (final rs in entry.value) {
          final sid = aptServiceToServiceId[rs.apartmentServiceId];
          if (sid == null) continue;
          final key = '${entry.key}|$sid';
          final price = (rs.chargedPrice ?? 0).toDouble();
          priceByResService[key] = price;
        }
      }
    }

    // -------------------------------------------------------------------------
    // Krok 3: AGREGACE PODLE ZAMĚSTNANCE (EmployeePerformance)
    // -------------------------------------------------------------------------
    // Pro každý dokončený úkol projdeme assigned_to (profile.id pracovníka). Úkol
    // přičteme do bucketu daného assigneeId (prázdný = Nepřiřazeno).
    // taskCount: jednoduchý počet úkolů (+1 za každý).
    // hoursWorked: primárně z reálných časů – pokud existují started_at i completed_at,
    // použijeme jejich rozdíl v minutách / 60. Když ne, fallback na metadata.estimated_minutes
    // (nebo estimate_minutes) z úkolu – odhad z katalogu služeb.
    //
    // -------------------------------------------------------------------------
    // Krok 4: AGREGACE PODLE BYTU (ApartmentRevenue)
    // -------------------------------------------------------------------------
    // Každý úkol má apartment_id. Cenu získáme z reservation_services přes klíč
    // (reservation_id|service_id) – charged_price je skutečná účtovaná cena v EUR.
    // Úkoly bez rezervace či bez shody v reservation_services mají cenu 0. Pro každý
    // apartment_id sečteme charged_price všech jeho úkolů → totalRevenue.
    // totalMonthRevenue = součet totalRevenue všech bytů.
    final byEmployee = <String, ({int count, double hours})>{};
    final byApartment = <String, double>{};

    for (final t in tasksInMonth) {
      final assigneeId = (t['assigned_to'] as String?)?.trim() ?? '';
      final aptId = (t['apartment_id'] as String?)?.trim() ?? '';
      final resId = (t['reservation_id'] as String?)?.trim() ?? '';
      final svcId = (t['service_id'] as String?)?.trim() ?? '';
      final key = '$resId|$svcId';
      final chargedPrice = priceByResService[key] ?? 0.0;

      // Agregace zaměstnance
      final current = byEmployee[assigneeId] ?? (count: 0, hours: 0.0);
      double hours = 0;
      final started = _parseDateTime(t['started_at']);
      final completed = _parseDateTime(t['completed_at']);
      if (started != null && completed != null) {
        hours = completed.difference(started).inMinutes / 60.0;
      } else {
        final meta = t['metadata'];
        if (meta is Map) {
          final raw = meta['estimated_minutes'] ?? meta['estimate_minutes'];
          if (raw != null) {
            if (raw is num) {
              hours = raw.toDouble() / 60.0;
            } else if (raw is String) {
              hours = (double.tryParse(raw) ?? 0) / 60.0;
            }
          }
        }
      }
      byEmployee[assigneeId] = (
        count: current.count + 1,
        hours: current.hours + hours,
      );

      // Agregace bytu (jen pokud má apartment_id)
      if (aptId.isNotEmpty) {
        byApartment[aptId] = (byApartment[aptId] ?? 0) + chargedPrice;
      }
    }

    final employeePerformances = byEmployee.entries
        .map((e) => EmployeePerformance(
              assigneeId: e.key,
              taskCount: e.value.count,
              hoursWorked: e.value.hours,
            ))
        .toList()
      ..sort((a, b) => b.taskCount.compareTo(a.taskCount));

    final apartmentRevenues = byApartment.entries
        .map((e) => ApartmentRevenue(
              apartmentId: e.key,
              totalRevenue: e.value,
            ))
        .toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    final totalMonthRevenue =
        apartmentRevenues.fold<double>(0, (s, a) => s + a.totalRevenue);

    return ReportsSummary(
      employeePerformances: employeePerformances,
      apartmentRevenues: apartmentRevenues,
      totalMonthRevenue: totalMonthRevenue,
      month: month,
      year: year,
    );
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Reports Data Error: $e');
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
