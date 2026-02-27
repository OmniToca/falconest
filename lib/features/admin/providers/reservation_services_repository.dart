import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/reservation_service_model.dart';

/// Načte všechny záznamy reservation_services pro dané rezervace (např. pro generátor úkolů).
/// Vrací mapu reservation_id -> seznam řádků.
/// [tenantId] – Přidáno filtrování podle tenant_id z důvodu defense-in-depth (V1_RELEASE_AUDIT).
Future<Map<String, List<ReservationServiceRow>>> fetchByReservationIds(
  List<String> reservationIds,
  String tenantId,
) async {
  if (reservationIds.isEmpty || tenantId.trim().isEmpty) return {};
  final ids = reservationIds.where((id) => id.isNotEmpty).toSet().toList();
  if (ids.isEmpty) return {};
  // PROČ explicitní select: zaručíme, že flight_number a payer_type (nativní sloupce) se vždy načtou.
  final res = await SupabaseService.client
      .from('reservation_services')
      .select('id, tenant_id, reservation_id, apartment_service_id, charged_price, custom_note, flight_number, payer_type, requires_photo')
      .eq('tenant_id', tenantId)
      .inFilter('reservation_id', ids);
  final list = (res as List).cast<Map<String, dynamic>>();
  final result = <String, List<ReservationServiceRow>>{};
  for (final e in list) {
    final row = ReservationServiceRow.fromJson(e);
    if (row.id.isEmpty) continue;
    result.putIfAbsent(row.reservationId, () => []).add(row);
  }
  return result;
}

/// Načte všechny záznamy reservation_services pro danou rezervaci (pro předvyplnění Tabu 2 v dialogu).
/// [tenantId] – Přidáno filtrování podle tenant_id z důvodu defense-in-depth (V1_RELEASE_AUDIT).
Future<List<ReservationServiceRow>> fetchByReservationId(
  String reservationId,
  String tenantId,
) async {
  if (reservationId.isEmpty || tenantId.trim().isEmpty) return [];
  // PROČ explicitní select: zaručíme načtení flight_number a payer_type (nativní sloupce pro transfery).
  final res = await SupabaseService.client
      .from('reservation_services')
      .select('id, tenant_id, reservation_id, apartment_service_id, charged_price, custom_note, flight_number, payer_type, requires_photo')
      .eq('tenant_id', tenantId)
      .eq('reservation_id', reservationId);
  final list = res as List;
  return list
      .map((e) => ReservationServiceRow.fromJson(e as Map<String, dynamic>))
      .where((r) => r.id.isNotEmpty)
      .toList();
}

/// Po uložení rezervace: smaže všechny reservation_services pro rezervaci a vloží nové (jen enabled).
/// [states] = mapa apartmentServiceId -> edit state; ukládají se jen záznamy s enabled == true.
/// Ceny [chargedPriceEur] se ukládají do sloupce charged_price v EUR.
Future<void> saveForReservation({
  required String reservationId,
  required String tenantId,
  required Map<String, ReservationServiceEditState> states,
}) async {
  final toInsert = states.values.where((s) => s.enabled).toList();
  // SECURITY FIX: Explicitní defense-in-depth kontrola na tenant_id.
  await SupabaseService.client
      .from('reservation_services')
      .delete()
      .eq('tenant_id', tenantId)
      .eq('reservation_id', reservationId);
  if (toInsert.isEmpty) return;
  // Mapování: flight_number a payer_type jako nativní sloupce (bez [FLIGHT:XXX] v custom_note).
  for (final s in toInsert) {
    await SupabaseService.client.from('reservation_services').insert({
      'tenant_id': tenantId,
      'reservation_id': reservationId,
      'apartment_service_id': s.apartmentServiceId,
      'charged_price': s.chargedPriceEur,
      'custom_note': s.customNote?.trim().isEmpty == true ? null : s.customNote?.trim(),
      'flight_number': s.flightNumber?.trim().isEmpty == true ? null : s.flightNumber?.trim(),
      'payer_type': (s.payerType == 'owner' || s.payerType == 'guest') ? s.payerType : null,
      'requires_photo': s.requiresPhoto,
    });
  }
}
