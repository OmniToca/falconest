import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/reservation_services_repository.dart';

/// Řádek fakturačního podkladu – agregace služeb za jednu rezervaci.
/// Výpočet podkladů pro fakturaci. Ignoruje nezaplacené hotovosti zaměstnanci,
/// bere pevná data z reservation_services podle plátce.
class BillingReportRow {
  const BillingReportRow({
    required this.reservationId,
    required this.apartmentName,
    required this.periodLabel,
    required this.totalValue,
    required this.cashCollected,
    required this.toInvoice,
  });

  final String reservationId;
  final String apartmentName;
  /// Formátované období rezervace (např. "1.3. – 15.3.2026").
  final String periodLabel;
  /// Služby celkem – součet charged_price ze všech reservation_services.
  final double totalValue;
  /// Vybráno v hotovosti – součet charged_price kde payer_type == 'guest'.
  final double cashCollected;
  /// K fakturaci majiteli – součet charged_price kde payer_type == 'owner'.
  final double toInvoice;
}

/// Parametr pro billing report – měsíc a rok.
class BillingMonthParam {
  const BillingMonthParam({required this.year, required this.month});
  final int year;
  final int month;
}

/// Načte fakturační podklady pro zvolený měsíc a rok.
/// Rezervace musí mít status 'checked_out' a konec pobytu (departure_time nebo end_date)
/// musí spadat do zvoleného měsíce.
final billingReportProvider =
    FutureProvider.family<List<BillingReportRow>, BillingMonthParam>((ref, param) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  final apartments = await ref.watch(apartmentsProvider.future);
  final apartmentIds = apartments.map((a) => a.id).where((id) => id.isNotEmpty).toList();
  if (apartmentIds.isEmpty) return [];

  final startOfMonth = DateTime.utc(param.year, param.month, 1);
  final startOfNextMonth = DateTime.utc(param.year, param.month + 1, 1);

  try {
    /// a) Rezervace s koncem pobytu (departure_time) v zvoleném měsíci a status checked_out.
    /// Filtrování na departure_time přímo v DB – timestamptz.
    final reservationsData = await SupabaseService.client
        .from('reservations')
        .select(
          'id, apartment_id, start_date, end_date, departure_time, apartments(name)',
        )
        .inFilter('apartment_id', apartmentIds)
        .eq('status', 'checked_out')
        .isFilter('deleted_at', null)
        .gte('departure_time', startOfMonth.toUtc().toIso8601String())
        .lt('departure_time', startOfNextMonth.toUtc().toIso8601String());

    final list = reservationsData as List;
    if (list.isEmpty) return [];
    final reservationIds = <String>[];
    final reservationData = <String, ({String apartmentName, String periodLabel})>{};

    for (final e in list) {
      final raw = e as Map<String, dynamic>;
      final id = (raw['id'] as String?)?.trim();
      if (id == null || id.isEmpty) continue;

      final apartmentId = (raw['apartment_id'] as String?)?.trim();
      if (apartmentId == null || apartmentId.isEmpty) continue;

      String apartmentName = '—';
      final apt = raw['apartments'];
      if (apt is Map && apt['name'] != null) {
        apartmentName = (apt['name'] as String?).toString().trim();
      }
      if (apartmentName.isEmpty) apartmentName = '—';

      final startRaw = raw['start_date'];
      final endRaw = raw['end_date'];
      String startStr = '—';
      String endStr = '—';
      if (startRaw != null) {
        final d = startRaw is DateTime ? startRaw : (startRaw is String ? DateTime.tryParse(startRaw) : null);
        if (d != null) startStr = '${d.day}.${d.month}.${d.year}';
      }
      if (endRaw != null) {
        final d = endRaw is DateTime ? endRaw : (endRaw is String ? DateTime.tryParse(endRaw) : null);
        if (d != null) endStr = '${d.day}.${d.month}.${d.year}';
      }
      final periodLabel = '$startStr – $endStr';

      reservationIds.add(id);
      reservationData[id] = (apartmentName: apartmentName, periodLabel: periodLabel);
    }

    /// Ochrana před voláním fetchByReservationIds s prázdným seznamem – Postgrest .inFilter vyvolá výjimku.
    if (reservationIds.isEmpty) return [];

    /// b) Načtení reservation_services pro všechny rezervace (tenant_id pro defense-in-depth).
    final servicesByRes = await fetchByReservationIds(reservationIds, tenantId);

    final rows = <BillingReportRow>[];

    for (final rid in reservationIds) {
      final data = reservationData[rid];
      if (data == null) continue;

      final services = servicesByRes[rid] ?? [];

      double totalValue = 0;
      double cashCollected = 0;
      double toInvoice = 0;

      for (final s in services) {
        final price = (s.chargedPrice ?? 0).toDouble();
        totalValue += price;

        final pt = (s.payerType ?? '').trim();
        if (pt == 'guest') {
          cashCollected += price;
        } else if (pt == 'owner') {
          toInvoice += price;
        }
      }

      rows.add(BillingReportRow(
        reservationId: rid,
        apartmentName: data.apartmentName,
        periodLabel: data.periodLabel,
        totalValue: totalValue,
        cashCollected: cashCollected,
        toInvoice: toInvoice,
      ));
    }

    rows.sort((a, b) => a.apartmentName.compareTo(b.apartmentName));
    return rows;
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
