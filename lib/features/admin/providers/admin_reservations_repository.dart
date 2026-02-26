import 'package:falconest/core/services/supabase_service.dart';

/// Repozitář pro rezervace v Admin modulu – Realtime stream.
///
/// Slouží pro okamžitou aktualizaci seznamu rezervací bez nutnosti F5.
/// Rezervace nemají tenant_id – filtrování probíhá přes apartment_id.
class AdminReservationsRepository {
  AdminReservationsRepository._();
  static final AdminReservationsRepository instance = AdminReservationsRepository._();

  /// Realtime stream rezervací pro dané byty (apartment_ids tenanta).
  ///
  /// PROČ: Realtime stream pro okamžitou aktualizaci UI bez nutnosti F5 (Supabase WebSockets).
  /// Dispečer vidí nové rezervace, změny termínů a stavů hned po úpravě.
  ///
  /// [apartmentIds] – seznam ID bytů náležících k aktuálnímu tenantovi.
  /// OMEZENÍ: Supabase stream podporuje pouze jeden filtr – používáme inFilter(apartment_id).
  /// Filtrování deleted_at a řazení probíhá na straně klienta.
  Stream<List<Map<String, dynamic>>> watchReservationsRaw(List<String> apartmentIds) {
    if (apartmentIds.isEmpty) return Stream.value([]);

    return SupabaseService.client
        .from('reservations')
        .stream(primaryKey: ['id'])
        .inFilter('apartment_id', apartmentIds)
        .map((List<Map<String, dynamic>> rows) {
          final filtered = rows
              .where((r) => r['deleted_at'] == null)
              .toList();
          filtered.sort((a, b) {
            final aVal = a['start_date']?.toString() ?? '';
            final bVal = b['start_date']?.toString() ?? '';
            return aVal.compareTo(bVal);
          });
          return filtered;
        });
  }
}
