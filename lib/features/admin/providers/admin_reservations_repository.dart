import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/supabase_stream_helper.dart';

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
  /// PROČ resilientSupabaseStream: Chyby WebSocketu (Code 1000) se nikdy nepropagují do Riverpodu.
  ///
  /// [apartmentIds] – seznam ID bytů náležících k aktuálnímu tenantovi.
  /// OMEZENÍ: Supabase stream podporuje pouze jeden filtr – používáme inFilter(apartment_id).
  ///
  /// PROČ hybridní přístup (initial fetch + stream): Supabase Realtime stream nemusí vždy
  /// emitovat úvodní data okamžitě. Bez initial fetch by StreamProvider zůstal v loading
  /// stavu (nekonečné kolečko v záložce „Služby a požadavky“ dialogu rezervace).
  Stream<List<Map<String, dynamic>>> watchReservationsRaw(List<String> apartmentIds) {
    if (apartmentIds.isEmpty) return Stream.value([]);

    List<Map<String, dynamic>> filterAndSort(List<Map<String, dynamic>> rows) {
      final filtered = rows
          .where((r) => r['deleted_at'] == null)
          .toList();
      filtered.sort((a, b) {
        final aVal = a['start_date']?.toString() ?? '';
        final bVal = b['start_date']?.toString() ?? '';
        return aVal.compareTo(bVal);
      });
      return filtered;
    }

    final stream = resilientSupabaseStream<List<Map<String, dynamic>>>(
      streamBuilder: () => SupabaseService.client
          .from('reservations')
          .stream(primaryKey: ['id'])
          .inFilter('apartment_id', apartmentIds)
          .order('start_date', ascending: false)
          .limit(500)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminReservationsRepository.watchReservationsRaw',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        final res = await SupabaseService.client
            .from('reservations')
            .select()
            .inFilter('apartment_id', apartmentIds)
            .order('start_date', ascending: false)
            .limit(500);
        final list = (res as List).cast<Map<String, dynamic>>();
        return filterAndSort(list);
      },
    );
  }

  /// Emituje nejdřív úvodní data z [initialFetch], pak pokračuje streamem.
  /// PROČ: Zajišťuje bleskové načtení bez čekání na první emit Supabase streamu.
  static Stream<T> _streamWithInitialFetch<T>({
    required Stream<T> stream,
    required Future<T> Function() initialFetch,
  }) async* {
    yield await initialFetch();
    yield* stream;
  }
}
