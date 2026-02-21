import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/models/reservation_service_model.dart';
import 'package:falconest/features/admin/providers/apartment_services_repository.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';

/// Pro vybraný byt vrací seznam služeb (apartment_services) s názvem a výchozí cenou z katalogu.
/// Používá se v Tabu „Služby a požadavky“ dialogu rezervace – dynamicky podle apartment_id.
final apartmentServicesOptionsProvider =
    FutureProvider.family<List<ApartmentServiceOption>, String>((ref, apartmentId) async {
  if (apartmentId.isEmpty) return [];
  final tenantServices = await ref.watch(tenantServicesProvider.future);
  final rows = await fetchByApartmentId(apartmentId);
  final serviceById = {for (final s in tenantServices) s.id: s};
  return rows.map((r) {
    final ts = serviceById[r.serviceId];
    final name = ts?.name ?? 'Služba';
    final defaultPrice = r.customPrice?.toDouble() ?? ts?.defaultPrice?.toDouble() ?? 0.0;
    final durationMinutes = ts?.durationMinutes ?? 0;
    return ApartmentServiceOption(
      apartmentServiceId: r.id,
      serviceId: r.serviceId,
      serviceName: name,
      defaultPriceEur: defaultPrice,
      isMandatory: r.isMandatory,
      payerType: r.payerType,
      durationMinutes: durationMinutes,
    );
  }).toList();
});
