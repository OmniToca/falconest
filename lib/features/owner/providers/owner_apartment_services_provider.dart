import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/reservation_service_model.dart';
import 'package:falconest/features/admin/providers/apartment_services_repository.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';

/// Služby bytu pro majitele – načte tenant_id z apartmánu, pak apartment_services.
/// Pro property_owner nemáme tenantIdForData, proto fetchneme tenant_id z bytu
/// a tenant_services přímo s tímto tenant_id.
/// FEATURE: Rozšířený formulář rezervace pro majitele (časy, hosté, služby).
final ownerApartmentServicesOptionsProvider =
    FutureProvider.autoDispose.family<List<ApartmentServiceOption>, String>((ref, apartmentId) async {
  if (apartmentId.isEmpty) return [];
  final aptRes = await SupabaseService.client
      .from('apartments')
      .select('tenant_id')
      .eq('id', apartmentId)
      .maybeSingle();
  final tenantId = aptRes?['tenant_id']?.toString();
  if (tenantId == null || tenantId.isEmpty) return [];
  final tenantServices = await TenantServicesRepository.fetchList(tenantId);
  final rows = await fetchByApartmentId(apartmentId, tenantId);
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
