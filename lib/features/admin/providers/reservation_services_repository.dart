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
  // PROČ timeout: Pojistka proti nekonečnému načítání – výjimka probublá do UI.
  const timeout = Duration(seconds: 10);
  final res = await SupabaseService.safeFrom('reservation_services', tenantId)
      .select('id, tenant_id, reservation_id, apartment_service_id, charged_price, transit_cash_to_collect, custom_note, flight_number, payer_type, requires_photo')
      .inFilter('reservation_id', ids)
      .timeout(timeout);
  final list = (res as List).cast<Map<String, dynamic>>();
  final result = <String, List<ReservationServiceRow>>{};
  for (final e in list) {
    final row = ReservationServiceRow.fromJson(e);
    if (row.id.isEmpty) continue;
    final key = row.reservationId.trim();
    result.putIfAbsent(key, () => []).add(row);
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
  // PROČ timeout: Pojistka proti nekonečnému načítání v Tabu 2 dialogu rezervace – výjimka probublá do UI.
  const timeout = Duration(seconds: 10);
  final res = await SupabaseService.safeFrom('reservation_services', tenantId)
      .select('id, tenant_id, reservation_id, apartment_service_id, charged_price, transit_cash_to_collect, custom_note, flight_number, payer_type, requires_photo')
      .eq('reservation_id', reservationId)
      .timeout(timeout);
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
  final safeRs = SupabaseService.safeFrom('reservation_services', tenantId);
  await safeRs.delete().eq('reservation_id', reservationId);
  if (toInsert.isEmpty) return;
  for (final s in toInsert) {
    await safeRs.insert({
      'reservation_id': reservationId,
      'apartment_service_id': s.apartmentServiceId,
      'charged_price': s.chargedPriceEur,
      'transit_cash_to_collect':
          (s.transitCashToCollectEur != null && s.transitCashToCollectEur! > 0)
              ? s.transitCashToCollectEur
              : null,
      'custom_note': s.customNote?.trim().isEmpty == true ? null : s.customNote?.trim(),
      'flight_number': s.flightNumber?.trim().isEmpty == true ? null : s.flightNumber?.trim(),
      'payer_type': (s.payerType == 'owner' || s.payerType == 'guest') ? s.payerType : null,
      'requires_photo': s.requiresPhoto,
    });
  }
}

/// Zajistí, že pro danou rezervaci existují řádky v reservation_services pro VŠECHNY povinné
/// služby daného apartmánu (is_mandatory = true v apartment_services). Vkládá jen chybějící řádky.
/// PROČ: Admin musí mít možnost u konkrétní rezervace přepsat cenu i u povinného úklidu; bez řádku
/// v reservation_services by si upravenou cenu neměl kam uložit. Volá se po každém saveForReservation.
Future<void> ensureMandatoryServicesForReservation({
  required String reservationId,
  required String tenantId,
  required String apartmentId,
}) async {
  if (reservationId.isEmpty || tenantId.isEmpty || apartmentId.isEmpty) return;
  const timeout = Duration(seconds: 10);

  final existing = await SupabaseService.safeFrom('reservation_services', tenantId)
      .select('apartment_service_id')
      .eq('reservation_id', reservationId)
      .timeout(timeout);
  final existingIds = <String>{
    for (final row in existing as List)
      ((row as Map<String, dynamic>)['apartment_service_id'] as String?)?.trim() ?? '',
  }..remove('');

  final mandatoryRaw = await SupabaseService.safeFrom('apartment_services', tenantId)
      .select('id, custom_price, payer_type, service_id')
      .eq('apartment_id', apartmentId)
      .eq('is_mandatory', true)
      .timeout(timeout);
  final mandatoryList = mandatoryRaw as List;
  if (mandatoryList.isEmpty) return;

  final catalogRaw = await SupabaseService.safeFrom('tenant_services', tenantId)
      .select('id, default_price')
      .timeout(timeout);
  final catalogById = <String, double?>{};
  for (final row in catalogRaw as List) {
    final m = row as Map<String, dynamic>;
    final id = (m['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) continue;
    final dp = m['default_price'];
    catalogById[id] = dp != null ? (dp is num ? dp.toDouble() : double.tryParse(dp.toString())) : null;
  }

  for (final row in mandatoryList) {
    final m = row as Map<String, dynamic>;
    final apartmentServiceId = (m['id'] as String?)?.trim() ?? '';
    if (apartmentServiceId.isEmpty || existingIds.contains(apartmentServiceId)) continue;

    final serviceId = (m['service_id'] as String?)?.trim() ?? '';
    double? chargedPrice;
    final cp = m['custom_price'];
    if (cp != null) {
      if (cp is num) {
        chargedPrice = cp.toDouble();
      } else {
        chargedPrice = double.tryParse(cp.toString());
      }
    }
    chargedPrice ??= catalogById[serviceId];

    final pt = (m['payer_type'] as String?)?.trim();
    final payerType = (pt == 'owner' || pt == 'guest') ? pt : 'owner';

    await SupabaseService.safeFrom('reservation_services', tenantId).insert({
      'reservation_id': reservationId,
      'apartment_service_id': apartmentServiceId,
      'charged_price': chargedPrice,
      'custom_note': null,
      'flight_number': null,
      'payer_type': payerType,
      'requires_photo': null,
    });
    existingIds.add(apartmentServiceId);
  }
}
