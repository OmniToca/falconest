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
///
/// PROČ select na auth: ref.watch(authNotifierProvider) by při každé notifikaci auth
/// invalidoval provider a přispíval k nekonečnému loading stavu v Tabu 2 (stejně jako u Finance).
/// .select((s) => s.tenantIdForData) omezí re-exekuci jen na změnu tenantId.
final apartmentServicesOptionsProvider =
    FutureProvider.autoDispose.family<List<ApartmentServiceOption>, String>((ref, apartmentId) async {
  if (apartmentId.isEmpty) return [];
  final tenantId = ref.read(authNotifierProvider.select((s) => s.tenantIdForData));
  if (tenantId == null || tenantId.isEmpty) return [];
  final tenantServices = await ref.read(tenantServicesProvider.future);
  final rows = await fetchByApartmentId(apartmentId, tenantId);
  final serviceById = {for (final s in tenantServices) s.id: s};
  final options = rows.map((r) {
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
      triggerType: r.triggerType,
      checklistTemplateId: r.checklistTemplateId,
    );
  }).toList();

  // Řazení podle pořadí z katalogu (tenant_services.order_index). Služby bez indexu na konec.
  options.sort((a, b) {
    final orderA = serviceById[a.serviceId]?.orderIndex ?? 999;
    final orderB = serviceById[b.serviceId]?.orderIndex ?? 999;
    return orderA.compareTo(orderB);
  });
  return options;
});

/// Vrací cenu služby pro manuální úkol – Historical pricing auto-fill.
///
/// Při výběru bytu a služby v Add Task dialogu načte cenu z apartment_services
/// (custom_price) nebo fallback na tenant_services.default_price. Oba parametry
/// musí být vyplněny; jinak vrací null.
final manualTaskServicePriceProvider =
    FutureProvider.autoDispose.family<double?, (String apartmentId, String serviceId)>((ref, param) async {
  final (apartmentId, serviceId) = param;
  if (apartmentId.isEmpty || serviceId.isEmpty) return null;
  final options = await ref.watch(apartmentServicesOptionsProvider(apartmentId).future);
  final match = options.where((o) => o.serviceId == serviceId).firstOrNull;
  if (match != null) return match.defaultPriceEur;
  final catalog = await ref.watch(tenantServicesProvider.future);
  final svc = catalog.where((s) => s.id == serviceId).firstOrNull;
  return svc?.defaultPrice?.toDouble();
});
