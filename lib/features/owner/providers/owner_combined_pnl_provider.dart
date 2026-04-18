import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/models/apartment_investment_pnl_entry.dart';
import 'package:falconest/features/owner/models/monthly_pnl_summary.dart';
import 'package:falconest/features/owner/providers/apartment_investment_pnl_entries_provider.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/providers/owner_billing_provider.dart';
import 'package:falconest/features/owner/services/owner_apartment_agency_costs_from_snapshots.dart';

/// Spojený měsíční P&L: manuální záznamy majitele + agenturní náklady z uzamčených faktur.
///
/// PROČ: UI výsledovky a ROI potřebují jeden seřazený seznam měsíců; [apartmentInvestmentPnlEntriesProvider]
/// drží jen ruční řádky, zde je doplníme o [MonthlyPnlSummary.agencyCosts] z [ownerBillingSnapshotsProvider].
/// Sleduje oba zdroje – po novém snapshotu nebo úpravě P&L stačí invalidace příslušného provideru.
final ownerCombinedPnlProvider = FutureProvider.autoDispose
    .family<List<MonthlyPnlSummary>, String>((ref, apartmentId) async {
  if (apartmentId.isEmpty) return [];

  final apartments = await ref.watch(ownerApartmentsProvider.future);
  final owned = apartments.map((a) => a.id).where((id) => id.isNotEmpty).toSet();
  if (!owned.contains(apartmentId)) return [];

  final results = await Future.wait([
    ref.watch(apartmentInvestmentPnlEntriesProvider(apartmentId).future),
    ref.watch(ownerBillingSnapshotsProvider.future),
  ]);

  final entries = results[0] as List<ApartmentInvestmentPnlEntry>;
  final snapshots = results[1] as List<BillingSnapshotModel>;

  final agencyByMonth = await OwnerApartmentAgencyCostsFromSnapshots.agencyCostsByMonth(
    apartmentId: apartmentId,
    ownerApartmentIds: owned.toList(),
    snapshots: snapshots,
  );

  final incomeByMonth = <DateTime, double>{};
  final expenseByMonth = <DateTime, double>{};

  for (final e in entries) {
    final m = DateTime.utc(e.entryMonth.year, e.entryMonth.month, 1);
    if (e.entryType == 'income') {
      incomeByMonth[m] = (incomeByMonth[m] ?? 0) + e.amount;
    } else if (e.entryType == 'expense') {
      expenseByMonth[m] = (expenseByMonth[m] ?? 0) + e.amount;
    }
  }

  final monthKeys = <DateTime>{}
    ..addAll(incomeByMonth.keys)
    ..addAll(expenseByMonth.keys)
    ..addAll(agencyByMonth.keys);

  final out = monthKeys
      .map(
        (mk) => MonthlyPnlSummary(
          month: mk,
          ownerIncome: incomeByMonth[mk] ?? 0,
          ownerExpense: expenseByMonth[mk] ?? 0,
          agencyCosts: agencyByMonth[mk] ?? 0,
        ),
      )
      .toList();

  out.sort((a, b) {
    final ca = DateTime.utc(a.month.year, a.month.month, 1);
    final cb = DateTime.utc(b.month.year, b.month.month, 1);
    return cb.compareTo(ca);
  });

  return out;
});
