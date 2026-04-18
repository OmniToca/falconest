import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/models/apartment_investment_metrics.dart';
import 'package:falconest/features/owner/repositories/owner_apartment_investment_metrics_repository.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';

/// Metriky investice pro jeden byt majitele (tabulka `apartment_investment_metrics`).
///
/// PROČ: Stejný „double guard“ jako [ownerApartmentDetailProvider] – bez vazby v
/// `ownerApartmentsProvider` se řádek vůbec nenačte (ochrana před enumerací cizích ID).
/// `null` = zatím žádný řádek v DB; UI zobrazí nuly a první uložení provede INSERT (RLS).
final apartmentInvestmentMetricsProvider = FutureProvider.autoDispose
    .family<ApartmentInvestmentMetrics?, String>((ref, apartmentId) async {
  if (apartmentId.isEmpty) return null;

  final apartments = await ref.watch(ownerApartmentsProvider.future);
  final owned = apartments.map((a) => a.id).where((id) => id.isNotEmpty).toSet();
  if (!owned.contains(apartmentId)) return null;

  return OwnerApartmentInvestmentMetricsRepository.fetchByApartmentId(apartmentId);
});
