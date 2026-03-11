import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
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

/// Ziskovost jednoho klienta za vybraný měsíc.
///
/// [clientId] = UUID klienta z CRM, nebo 'external'/'unknown' pro syntetické buckety.
/// [clientName] = zobrazené jméno (z clients.name nebo i18n fallback).
/// [totalRevenue] = součet tržeb všech úkolů přiřazených tomuto klientovi.
class ClientRevenue {
  const ClientRevenue({
    required this.clientId,
    required this.clientName,
    required this.totalRevenue,
  });

  final String clientId;
  final String clientName;
  final double totalRevenue;
}

/// Obálka agregovaných dat pro modul Reporty.
class ReportsSummary {
  const ReportsSummary({
    required this.employeePerformances,
    required this.apartmentRevenues,
    required this.clientRevenues,
    required this.totalMonthRevenue,
    required this.month,
    required this.year,
  });

  final List<EmployeePerformance> employeePerformances;
  final List<ApartmentRevenue> apartmentRevenues;
  final List<ClientRevenue> clientRevenues;
  /// Celková tržba za měsíc (součet totalRevenue všech apartmánů + klientů).
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
      clientRevenues: [],
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

  final apartments = ref.watch(apartmentsFullListProvider).valueOrNull ?? [];
  final startOfReportMonth = DateTime.utc(year, month, 1);
  final monthlyFeeSum = apartments.fold<double>(
      0, (sum, apt) {
        if (apt.managedFrom != null) {
          final firstDayManaged = DateTime.utc(apt.managedFrom!.year, apt.managedFrom!.month, 1);
          if (startOfReportMonth.isBefore(firstDayManaged)) return sum;
        }
        return sum + apt.monthlyManagementFee;
      });

  try {
    // Krok 1: Načti dokončené úkoly tenantu POUZE pro vybraný měsíc (časové okno v DB).
    // PROČ: Výkon – bez filtru by se stahovala celá historie (OOM při 10 000+ úkolech).
    // Reporty používají completed_at jako primární datum pro zařazení do měsíce.
    final startIso = startOfMonth.toIso8601String();
    final endIso = startOfNextMonth.toIso8601String();
    final tasksRes = await SupabaseService.client
        .from('tasks')
        .select(
          'id, title, task_type, apartment_id, reservation_id, service_id, client_id, '
          'completed_at, due_date, scheduled_start, assigned_to, started_at, metadata',
        )
        .eq('tenant_id', tenantId)
        .eq('status', 'completed')
        .isFilter('deleted_at', null)
        .gte('completed_at', startIso)
        .lt('completed_at', endIso)
        .limit(2000);

    final tasksList = (tasksRes as List).cast<Map<String, dynamic>>();
    if (tasksList.isEmpty) {
      return ReportsSummary(
        employeePerformances: [],
        apartmentRevenues: [],
        clientRevenues: [],
        totalMonthRevenue: monthlyFeeSum,
        month: month,
        year: year,
      );
    }

    // Úkoly jsou již vyfiltrované podle měsíce v DB; použijeme je přímo.
    final tasksInMonth = tasksList;

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

    // Krok 2b: Batch dotazy pro mapování bytu a profilu na klienta (N+1 prevention).
    // apartment_owners: apartment_id -> owner_id (profile). clients: id/profile_id -> name.
    final apartmentIdsFromTasks = tasksInMonth
        .map((t) => (t['apartment_id'] as String?)?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final clientIdsFromTasks = tasksInMonth
        .map((t) => (t['client_id'] as String?)?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final apartmentToOwnerId = <String, String>{};
    final ownerIdToClientId = <String, String>{};
    final clientIdToName = <String, String>{};

    if (apartmentIdsFromTasks.isNotEmpty) {
      final ownersRes = await SupabaseService.client
          .from('apartment_owners')
          .select('apartment_id, owner_id')
          .inFilter('apartment_id', apartmentIdsFromTasks)
          .isFilter('deleted_at', null);
      for (final row in (ownersRes as List)) {
        final m = row as Map<String, dynamic>;
        final aptId = (m['apartment_id'] as String?)?.trim();
        final ownerId = (m['owner_id'] as String?)?.trim();
        if (aptId != null && aptId.isNotEmpty && ownerId != null && ownerId.isNotEmpty) {
          apartmentToOwnerId.putIfAbsent(aptId, () => ownerId);
        }
      }
    }

    final profileIdsToFetch = apartmentToOwnerId.values.toSet().toList();
    if (profileIdsToFetch.isNotEmpty) {
      final clientsByProfileRes = await SupabaseService.client
          .from('clients')
          .select('id, name, profile_id')
          .eq('tenant_id', tenantId)
          .inFilter('profile_id', profileIdsToFetch)
          .isFilter('deleted_at', null);
      for (final row in (clientsByProfileRes as List)) {
        final m = row as Map<String, dynamic>;
        final id = (m['id'] as String?)?.trim();
        final name = (m['name'] as String?)?.trim();
        final profileId = (m['profile_id'] as String?)?.trim();
        if (id == null || id.isEmpty) continue;
        if (name != null && name.isNotEmpty) clientIdToName[id] = name;
        if (profileId != null && profileId.isNotEmpty) ownerIdToClientId[profileId] = id;
      }
    }
    if (clientIdsFromTasks.isNotEmpty) {
      final clientsDirectRes = await SupabaseService.client
          .from('clients')
          .select('id, name')
          .eq('tenant_id', tenantId)
          .inFilter('id', clientIdsFromTasks)
          .isFilter('deleted_at', null);
      for (final row in (clientsDirectRes as List)) {
        final m = row as Map<String, dynamic>;
        final id = (m['id'] as String?)?.trim();
        final name = (m['name'] as String?)?.trim();
        if (id != null && id.isNotEmpty && name != null && name.isNotEmpty) {
          clientIdToName[id] = name;
        }
      }
    }
    final apartmentToClientId = <String, String>{};
    for (final e in apartmentToOwnerId.entries) {
      final cid = ownerIdToClientId[e.value];
      if (cid != null) apartmentToClientId[e.key] = cid;
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
    // PROČ: Fallback logika cen – primárně metadata.amount_to_collect (ručně vybraná
    // hotovost), jinak reservation_services.charged_price. Dvojí agregace: byty + klienti.
    final byEmployee = <String, ({int count, double hours})>{};
    final byApartment = <String, double>{};
    final byClient = <String, ({String clientId, String clientName, double revenue})>{};

    for (final t in tasksInMonth) {
      final assigneeId = (t['assigned_to'] as String?)?.trim() ?? '';
      final aptId = (t['apartment_id'] as String?)?.trim() ?? '';
      final clientIdRaw = (t['client_id'] as String?)?.trim() ?? '';
      final resId = (t['reservation_id'] as String?)?.trim() ?? '';
      final svcId = (t['service_id'] as String?)?.trim() ?? '';
      final resSvcKey = '$resId|$svcId';
      final fallbackPrice = priceByResService[resSvcKey] ?? 0.0;
      final meta = t['metadata'];
      // Historical pricing – kaskáda priorit pro obrat úkolu.
      // service_price = zamražená cena u manuálních úkolů; amount_to_collect = hotovost; charged_price = rezervace.
      double? servicePrice;
      double? amountToCollect;
      if (meta is Map) {
        servicePrice = double.tryParse((meta['service_price']?.toString() ?? '').trim());
        amountToCollect = double.tryParse((meta['amount_to_collect']?.toString() ?? '').trim());
      }
      final finalPrice = servicePrice ?? amountToCollect ?? fallbackPrice;

      // Agregace zaměstnance
      final current = byEmployee[assigneeId] ?? (count: 0, hours: 0.0);
      double hours = 0;
      final started = _parseDateTime(t['started_at']);
      final completed = _parseDateTime(t['completed_at']);
      if (started != null && completed != null) {
        hours = completed.difference(started).inMinutes / 60.0;
      } else {
        final metaHours = t['metadata'];
        if (metaHours is Map) {
          final raw = metaHours['estimated_minutes'] ?? metaHours['estimate_minutes'];
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

      // Agregace A (Apartmány): apartment_id nebo 'external'.
      final aptBucketKey = aptId.isNotEmpty ? aptId : 'external';
      byApartment[aptBucketKey] = (byApartment[aptBucketKey] ?? 0) + finalPrice;

      // Agregace B (Klienti): client_id přímo, nebo apartment->owner->client, nebo 'unknown'.
      String clientBucketId;
      String clientBucketName;
      if (clientIdRaw.isNotEmpty) {
        clientBucketId = clientIdRaw;
        clientBucketName = clientIdToName[clientIdRaw] ?? clientIdRaw;
      } else if (aptId.isNotEmpty) {
        final derivedClientId = apartmentToClientId[aptId];
        if (derivedClientId != null) {
          clientBucketId = derivedClientId;
          clientBucketName = clientIdToName[derivedClientId] ?? derivedClientId;
        } else {
          clientBucketId = 'unknown';
          clientBucketName = '';
        }
      } else {
        clientBucketId = 'external';
        clientBucketName = '';
      }
      final clientKey = clientBucketId;
      final prev = byClient[clientKey];
      byClient[clientKey] = (
        clientId: clientBucketId,
        clientName: prev?.clientName ?? clientBucketName,
        revenue: (prev?.revenue ?? 0) + finalPrice,
      );
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

    final clientRevenues = byClient.entries
        .map((e) => ClientRevenue(
              clientId: e.value.clientId,
              clientName: e.value.clientName,
              totalRevenue: e.value.revenue,
            ))
        .toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    final revenueFromTasks =
        apartmentRevenues.fold<double>(0, (s, a) => s + a.totalRevenue);
    final totalMonthRevenue = revenueFromTasks + monthlyFeeSum;

    return ReportsSummary(
      employeePerformances: employeePerformances,
      apartmentRevenues: apartmentRevenues,
      clientRevenues: clientRevenues,
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
