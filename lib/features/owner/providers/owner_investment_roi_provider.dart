import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/models/apartment_investment_metrics.dart';
import 'package:falconest/features/owner/providers/apartment_investment_metrics_provider.dart';
import 'package:falconest/features/owner/providers/owner_combined_pnl_provider.dart';

/// Výsledek výpočtu ROI pro investiční přehled majitele.
///
/// PROČ: Oddělený stav (loading / dash / číslo) aby UI nemuselo duplikovat logiku
/// kombinace dvou async zdrojů.
class OwnerInvestmentRoiView {
  const OwnerInvestmentRoiView.loading()
      : isLoading = true,
        hasError = false,
        showDash = false,
        totalReturn = null;

  const OwnerInvestmentRoiView.error()
      : isLoading = false,
        hasError = true,
        showDash = true,
        totalReturn = null;

  /// Metriky v DB chybí – nelze spočítat kapitálovou složku spolehlivě.
  const OwnerInvestmentRoiView.incomplete()
      : isLoading = false,
        hasError = false,
        showDash = true,
        totalReturn = null;

  const OwnerInvestmentRoiView.ready(double value)
      : isLoading = false,
        hasError = false,
        showDash = false,
        totalReturn = value;

  final bool isLoading;
  final bool hasError;

  /// `true` → zobrazit „–“ místo částky.
  final bool showDash;
  final double? totalReturn;
}

/// Celkový výnos: (tržní hodnota − vstupní investice) + Σ měsíční čistý zisk.
///
/// Vstupní investice = kupní cena + počáteční rekonstrukce z [ApartmentInvestmentMetrics].
/// Čistý zisk za měsíc = příjmy − vlastní výdaje − agenturní náklady ([ownerCombinedPnlProvider]).
final ownerInvestmentRoiProvider =
    Provider.autoDispose.family<OwnerInvestmentRoiView, String>((ref, apartmentId) {
  if (apartmentId.isEmpty) {
    return const OwnerInvestmentRoiView.incomplete();
  }

  final metricsAsync = ref.watch(apartmentInvestmentMetricsProvider(apartmentId));
  final combinedAsync = ref.watch(ownerCombinedPnlProvider(apartmentId));

  if (metricsAsync.isLoading || combinedAsync.isLoading) {
    return const OwnerInvestmentRoiView.loading();
  }
  if (metricsAsync.hasError || combinedAsync.hasError) {
    return const OwnerInvestmentRoiView.error();
  }

  final ApartmentInvestmentMetrics? metrics = metricsAsync.valueOrNull;
  if (metrics == null) {
    return const OwnerInvestmentRoiView.incomplete();
  }

  final summaries = combinedAsync.valueOrNull ?? [];
  var netMonthlySum = 0.0;
  for (final s in summaries) {
    netMonthlySum += s.ownerIncome - s.ownerExpense - s.agencyCosts;
  }

  final entryInvestment = metrics.purchasePrice + metrics.initialRenovationCost;
  final capitalComponent = metrics.estimatedMarketPrice - entryInvestment;
  final total = capitalComponent + netMonthlySum;

  return OwnerInvestmentRoiView.ready(total);
});
