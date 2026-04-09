import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/reservation_service_model.dart';
import 'package:falconest/features/admin/providers/apartment_services_repository.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';

/// Služby bytu pro majitele – načte tenant_id z apartmánu, pak apartment_services.
/// Pro property_owner nemáme tenantIdForData, proto fetchneme tenant_id z bytu
/// a tenant_services přímo s tímto tenant_id.
/// SECURITY: Služby načteme jen pro byt, který majitel vlastní (kontrola přes ownerApartmentsProvider).
/// ROBUSTNESS: Celý dotaz v try-catch + timeout 2 s – provider VŽDY vrátí (data nebo []),
/// aby nedošlo k nekonečnému načítání (infinite loading) v sekci Služby.
final ownerApartmentServicesOptionsProvider =
    FutureProvider.autoDispose.family<List<ApartmentServiceOption>, String>((ref, apartmentId) async {
  // ignore: avoid_print
  print('--- SERVICES: Start pro byt $apartmentId');
  if (apartmentId.isEmpty) {
    // ignore: avoid_print
    print('--- SERVICES: apartmentId prázdný, vracím []');
    return [];
  }

  try {
    final result = await _loadOwnerServices(ref, apartmentId).timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        // ignore: avoid_print
        print('--- SERVICES: TIMEOUT 2s – vracím prázdný seznam');
        return <ApartmentServiceOption>[];
      },
    );
    // ignore: avoid_print
    print('--- SERVICES: Hotovo, ${result.length} položek');
    return result;
  } catch (e, stack) {
    // ignore: avoid_print
    print('owner_apartment_services_provider: $e');
    // ignore: avoid_print
    print(stack);
    return [];
  }
});

/// Vnitřní načtení – bez timeoutu (timeout je v nadřazeném provideru).
/// Používá ref.read(ownerApartmentsProvider.future) – žádný watch, aby nedošlo k re-evaluaci smyčce.
Future<List<ApartmentServiceOption>> _loadOwnerServices(Ref ref, String apartmentId) async {
  // ignore: avoid_print
  print('--- SERVICES: Získávám vlastněné byty (ref.read)');
  final ownedApartments = await ref.read(ownerApartmentsProvider.future);
  final ownedIds = ownedApartments.map((a) => a.id).where((id) => id.isNotEmpty).toSet();
  if (!ownedIds.contains(apartmentId)) {
    // ignore: avoid_print
    print('--- SERVICES: Byt není ve vlastnictví, vracím []');
    return [];
  }
  // ignore: avoid_print
  print('--- SERVICES: Získáno vlastnictví, načítám tenant_id z apartments');
  final aptRes = await SupabaseService.client
      .from('apartments')
      .select('tenant_id')
      .eq('id', apartmentId)
      .maybeSingle();
  final tenantId = aptRes?['tenant_id']?.toString();
  if (tenantId == null || tenantId.isEmpty) {
    // ignore: avoid_print
    print('--- SERVICES: Byt nemá tenant_id, vracím []');
    return [];
  }
  // ignore: avoid_print
  print('--- SERVICES: Načítám tenant_services a apartment_services');
  final tenantServices = await TenantServicesRepository.fetchList(tenantId);
  final rows = await fetchByApartmentId(apartmentId, tenantId);
  final serviceById = {for (final s in tenantServices) s.id: s};
  return rows
      .map((r) {
        final ts = serviceById[r.serviceId];
        final name = ts?.name ?? 'Služba';
        final defaultPrice =
            r.customPrice?.toDouble() ?? ts?.defaultPrice?.toDouble() ?? 0.0;
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
      })
      .where(_shouldShowApartmentServiceToOwner)
      .toList();
}

/// Zda má majitel službu v přehledu vidět – skryje bezplatné „interní“ řádky bez povinné akce.
///
/// PROČ: Cena 0 EUR u `on_demand` bez fotky, checklistu a povinnosti je často jen technický
/// řádek; povinné služby, focení, checklist nebo jiný trigger než on_demand stále zobrazíme.
bool _shouldShowApartmentServiceToOwner(ApartmentServiceOption o) {
  final price = o.defaultPriceEur;
  if (price > 0) return true;
  if (o.isMandatory) return true;
  if (o.requiresPhotoFromApartment == true || o.requiresPhotoFromCatalog) {
    return true;
  }
  final tpl = o.checklistTemplateId?.trim();
  if (tpl != null && tpl.isNotEmpty) return true;
  if (o.triggerType != 'on_demand') return true;
  return false;
}
