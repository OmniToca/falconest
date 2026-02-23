import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/reservation_service_model.dart';

/// Načte všechny záznamy reservation_services pro dané rezervace (např. pro generátor úkolů).
/// Vrací mapu reservation_id -> seznam řádků.
Future<Map<String, List<ReservationServiceRow>>> fetchByReservationIds(
  List<String> reservationIds,
) async {
  if (reservationIds.isEmpty) return {};
  final ids = reservationIds.where((id) => id.isNotEmpty).toSet().toList();
  if (ids.isEmpty) return {};
  final res = await SupabaseService.client
      .from('reservation_services')
      .select()
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
Future<List<ReservationServiceRow>> fetchByReservationId(String reservationId) async {
  if (reservationId.isEmpty) return [];
  final res = await SupabaseService.client
      .from('reservation_services')
      .select()
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
  await SupabaseService.client
      .from('reservation_services')
      .delete()
      .eq('reservation_id', reservationId);
  if (toInsert.isEmpty) return;
  for (final s in toInsert) {
    await SupabaseService.client.from('reservation_services').insert({
      'tenant_id': tenantId,
      'reservation_id': reservationId,
      'apartment_service_id': s.apartmentServiceId,
      'charged_price': s.chargedPriceEur,
      'custom_note': s.customNote?.trim().isEmpty == true ? null : s.customNote?.trim(),
      'payer_type': (s.payerType == 'owner' || s.payerType == 'guest') ? s.payerType : null,
    });
  }
}
