import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/models/reservation_service_model.dart';
import 'package:falconest/features/admin/providers/apartment_services_repository.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';

/// Pro vybraný byt vrací seznam služeb (apartment_services) s názvem a výchozí cenou z katalogu.
/// Používá se v Tabu „Služby a požadavky“ dialogu rezervace – dynamicky podle apartment_id.
///
/// PROČ ref.read pro tenantServicesProvider: ref.watch() vytváří závislost – při každé změně
/// katalogu by se provider invalidoval a znovu načítal. V kontextu dialogu rezervace to mohlo
/// vést k nekonečnému cyklu (stream refactor). ref.read() zajistí jedno načtení bez reaktivity.
final apartmentServicesOptionsProvider =
    FutureProvider.family<List<ApartmentServiceOption>, String>((ref, apartmentId) async {
  if (apartmentId.isEmpty) return [];
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];
  final tenantServices = await ref.read(tenantServicesProvider.future);
  final rows = await fetchByApartmentId(apartmentId, tenantId);
  final serviceById = {for (final s in tenantServices) s.id: s};
  return rows.map((r) {
    final ts = serviceById[r.serviceId];
    final name = ts?.name ?? 'admin.service_fallback'.tr();
    final defaultPrice = r.customPrice?.toDouble() ?? ts?.defaultPrice?.toDouble() ?? 0.0;
    final durationMinutes = ts?.durationMinutes ?? 0;
    return ApartmentServiceOption(
      apartmentServiceId: r.id,
      serviceId: r.serviceId,
      serviceName: name,
      defaultPriceEur: defaultPrice,
      serviceType: ts?.serviceType.trim().toLowerCase() ?? 'extra',
      isMandatory: r.isMandatory,
      payerType: r.payerType,
      durationMinutes: durationMinutes,
      requiresPhotoFromApartment: r.requiresPhoto,
      requiresPhotoFromCatalog: ts?.requiresPhoto ?? false,
    );
  }).toList();
});
