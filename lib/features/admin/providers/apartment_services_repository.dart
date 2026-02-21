import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/apartment_service_model.dart';

/// Načte všechny záznamy apartment_services pro daný byt (pro předvyplnění Tabu 2 v dialogu).
Future<List<ApartmentServiceRow>> fetchByApartmentId(String apartmentId) async {
  if (apartmentId.isEmpty) return [];
  final res = await SupabaseService.client
      .from('apartment_services')
      .select()
      .eq('apartment_id', apartmentId);
  final list = res as List;
  return list
      .map((e) => ApartmentServiceRow.fromJson(e as Map<String, dynamic>))
      .where((r) => r.id.isNotEmpty)
      .toList();
}

/// Dvoukrokový zápis: nejdřív smaže všechny stávající apartment_services pro byt, pak vloží nové (jen enabled).
/// [states] = mapa serviceId -> edit state; ukládají se jen záznamy s enabled == true.
/// Ceny [customPriceEur] se ukládají do sloupce custom_price v EUR.
Future<void> saveForApartment({
  required String apartmentId,
  required String tenantId,
  required Map<String, ApartmentServiceEditState> states,
}) async {
  final toInsert = states.values.where((s) => s.enabled).toList();
  await SupabaseService.client
      .from('apartment_services')
      .delete()
      .eq('apartment_id', apartmentId);
  if (toInsert.isEmpty) return;
  for (final s in toInsert) {
    await SupabaseService.client.from('apartment_services').insert({
      'tenant_id': tenantId,
      'apartment_id': apartmentId,
      'service_id': s.serviceId,
      'custom_price': s.customPriceEur,
      'custom_description': s.customDescription?.trim().isEmpty == true ? null : s.customDescription?.trim(),
      'trigger_type': s.triggerType,
      'schedule_interval': s.scheduleInterval?.trim().isEmpty == true ? null : s.scheduleInterval?.trim(),
      'is_mandatory': s.isMandatory,
      'payer_type': s.payerType,
    });
  }
}
