import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/models/apartment_investment_pnl_entry.dart';
import 'package:falconest/features/owner/repositories/owner_apartment_pnl_repository.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';

/// Seznam P&L řádků pro jeden byt majitele.
///
/// PROČ: Stejná kontrola vlastnictví jako u metrik; bez ní by šlo teoreticky zadat cizí UUID.
final apartmentInvestmentPnlEntriesProvider = FutureProvider.autoDispose
    .family<List<ApartmentInvestmentPnlEntry>, String>((ref, apartmentId) async {
  if (apartmentId.isEmpty) return [];

  final apartments = await ref.watch(ownerApartmentsProvider.future);
  final owned = apartments.map((a) => a.id).where((id) => id.isNotEmpty).toSet();
  if (!owned.contains(apartmentId)) return [];

  return OwnerApartmentPnlRepository.fetchByApartmentId(apartmentId);
});
