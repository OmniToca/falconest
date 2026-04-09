import 'package:easy_localization/easy_localization.dart';

import 'package:falconest/core/audit/enterprise_audit_payload.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/utils/supabase_stream_helper.dart';

/// Repozitář pro rezervace v Admin moduli – Realtime stream + zápisové operace.
///
/// Slouží pro okamžitou aktualizaci seznamu rezervací bez nutnosti F5.
/// Tabulka [reservations] má sloupec [tenant_id] (RLS doplňuje kontext přes apartmány);
/// [safeFrom] na klientovi vynutí konzistentní tenant filtr vedle RLS.
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
  /// [tenantId] – `tenantIdForData`; [safeFrom] vynutí tenant filtr i pro Super Admina
  /// (stream dříve šel přes holý [SupabaseService.client]).
  /// OMEZENÍ: Supabase stream podporuje pouze jeden inFilter – tenant řeší [safeFrom],
  /// apartmány filtrujeme v map() po přijetí řádků (stejně jako u transakcí peněženky).
  ///
  /// PROČ hybridní přístup (initial fetch + stream): Supabase Realtime stream nemusí vždy
  /// emitovat úvodní data okamžitě. Bez initial fetch by StreamProvider zůstal v loading
  /// stavu (nekonečné kolečko v záložce „Služby a požadavky“ dialogu rezervace).
  Stream<List<Map<String, dynamic>>> watchReservationsRaw(
    List<String> apartmentIds,
    String tenantId,
  ) {
    if (apartmentIds.isEmpty || tenantId.trim().isEmpty) return Stream.value([]);
    final aptSet = apartmentIds.toSet();

    List<Map<String, dynamic>> filterAndSort(List<Map<String, dynamic>> rows) {
      final filtered = rows
          .where((r) =>
              r['deleted_at'] == null &&
              aptSet.contains(r['apartment_id']?.toString()))
          .toList();
      filtered.sort((a, b) {
        final aVal = a['start_date']?.toString() ?? '';
        final bVal = b['start_date']?.toString() ?? '';
        return aVal.compareTo(bVal);
      });
      return filtered;
    }

    // Realtime: jen jeden inFilter – [safeFrom] ho použije pro tenant_id; byty dořežeme v [filterAndSort].
    final stream = resilientSupabaseStream<List<Map<String, dynamic>>>(
      streamBuilder: () => SupabaseService.safeFrom('reservations', tenantId)
          .stream(primaryKey: ['id'])
          .order('start_date', ascending: false)
          .limit(500)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminReservationsRepository.watchReservationsRaw',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        // Select (Postgrest) umožní tenant z [safeFrom] i inFilter bytů najednou.
        final res = await SupabaseService.safeFrom('reservations', tenantId)
            .select()
            .inFilter('apartment_id', apartmentIds)
            .order('start_date', ascending: false)
            .limit(500);
        final list = (res as List).cast<Map<String, dynamic>>();
        return filterAndSort(list);
      },
    );
  }

  /// ISO datum yyyy-MM-dd z lokálního kalendářního dne (bez času).
  static String _isoLocalDate(DateTime localDay) {
    final d = DateTime(localDay.year, localDay.month, localDay.day);
    return d.toIso8601String().split('T').first;
  }

  /// Rezervace překrývající **aktuální kalendářní měsíc** (lokální čas).
  ///
  /// PROČ: Karta bytu počítá obsazenost z přesného řezu v SQL (`start_date` ≤ konec měsíce,
  /// `end_date` ≥ začátek měsíce), ne z globálního streamu s limitem 500 řádků.
  /// Realtime větev filtruje až 8000 nejnovějších podle start_date – pro typické agency stačí;
  /// úvodní fetch je vždy přesný.
  Stream<List<Map<String, dynamic>>> watchReservationsOverlappingCurrentMonth(
    List<String> apartmentIds,
    String tenantId,
  ) {
    if (apartmentIds.isEmpty || tenantId.trim().isEmpty) return Stream.value([]);
    final aptSet = apartmentIds.toSet();

    bool overlapsCurrentMonth(Map<String, dynamic> r) {
      if (r['deleted_at'] != null) return false;
      if (!aptSet.contains(r['apartment_id']?.toString())) return false;
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);
      final sd = r['start_date']?.toString();
      final ed = r['end_date']?.toString();
      if (sd == null || ed == null) return false;
      final s = DateTime.tryParse(sd.length >= 10 ? sd.substring(0, 10) : sd);
      final e = DateTime.tryParse(ed.length >= 10 ? ed.substring(0, 10) : ed);
      if (s == null || e == null) return false;
      final sDay = DateTime(s.year, s.month, s.day);
      final eDay = DateTime(e.year, e.month, e.day);
      return !sDay.isAfter(monthEnd) && !eDay.isBefore(monthStart);
    }

    List<Map<String, dynamic>> filterAndSort(List<Map<String, dynamic>> rows) {
      final filtered = rows.where(overlapsCurrentMonth).toList();
      filtered.sort((a, b) {
        final aVal = a['start_date']?.toString() ?? '';
        final bVal = b['start_date']?.toString() ?? '';
        return aVal.compareTo(bVal);
      });
      return filtered;
    }

    final stream = resilientSupabaseStream<List<Map<String, dynamic>>>(
      streamBuilder: () => SupabaseService.safeFrom('reservations', tenantId)
          .stream(primaryKey: ['id'])
          .order('start_date', ascending: false)
          .limit(8000)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminReservationsRepository.watchReservationsOverlappingCurrentMonth',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 0);
        final startStr = _isoLocalDate(monthStart);
        final endStr = _isoLocalDate(monthEnd);
        final res = await SupabaseService.safeFrom('reservations', tenantId)
            .select()
            .inFilter('apartment_id', apartmentIds)
            .isFilter('deleted_at', null)
            .lte('start_date', endStr)
            .gte('end_date', startStr)
            .order('start_date', ascending: true);
        final list = (res as List).cast<Map<String, dynamic>>();
        return filterAndSort(list);
      },
    );
  }

  /// Rezervace v časovém okně potřebném pro výpočet denního stavu bytu (obsazeno / úklid).
  ///
  /// PROČ: Překryv [dnes − 400 dní, zítra] vyloučí celou historii, ale zachytí checkouty
  /// i aktivní pobyty – bez závislosti na limitu 500 u globálního admin streamu.
  Stream<List<Map<String, dynamic>>> watchReservationsForApartmentStatusContext(
    List<String> apartmentIds,
    String tenantId,
  ) {
    if (apartmentIds.isEmpty || tenantId.trim().isEmpty) return Stream.value([]);
    final aptSet = apartmentIds.toSet();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rangeStart = today.subtract(const Duration(days: 400));
    final tomorrow = today.add(const Duration(days: 1));
    final startStr = _isoLocalDate(rangeStart);
    final endStr = _isoLocalDate(tomorrow);

    bool inStatusWindow(Map<String, dynamic> r) {
      if (r['deleted_at'] != null) return false;
      if (!aptSet.contains(r['apartment_id']?.toString())) return false;
      final sd = r['start_date']?.toString();
      final ed = r['end_date']?.toString();
      if (sd == null || ed == null) return false;
      final s = DateTime.tryParse(sd.length >= 10 ? sd.substring(0, 10) : sd);
      final e = DateTime.tryParse(ed.length >= 10 ? ed.substring(0, 10) : ed);
      if (s == null || e == null) return false;
      final sDay = DateTime(s.year, s.month, s.day);
      final eDay = DateTime(e.year, e.month, e.day);
      final rangeEndDay = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      final rangeStartDay = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      return !sDay.isAfter(rangeEndDay) && !eDay.isBefore(rangeStartDay);
    }

    List<Map<String, dynamic>> filterAndSort(List<Map<String, dynamic>> rows) {
      final filtered = rows.where(inStatusWindow).toList();
      filtered.sort((a, b) {
        final aVal = a['start_date']?.toString() ?? '';
        final bVal = b['start_date']?.toString() ?? '';
        return aVal.compareTo(bVal);
      });
      return filtered;
    }

    final stream = resilientSupabaseStream<List<Map<String, dynamic>>>(
      streamBuilder: () => SupabaseService.safeFrom('reservations', tenantId)
          .stream(primaryKey: ['id'])
          .order('start_date', ascending: false)
          .limit(8000)
          .map((List<Map<String, dynamic>> rows) => filterAndSort(rows)),
      debugLabel: 'AdminReservationsRepository.watchReservationsForApartmentStatusContext',
    );

    return _streamWithInitialFetch(
      stream: stream,
      initialFetch: () async {
        final res = await SupabaseService.safeFrom('reservations', tenantId)
            .select()
            .inFilter('apartment_id', apartmentIds)
            .isFilter('deleted_at', null)
            .lte('start_date', endStr)
            .gte('end_date', startStr)
            .order('start_date', ascending: true);
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

  /// Soft-delete rezervace a navázaných úkolů (reservation_id), včetně Enterprise auditu.
  ///
  /// PROČ: Dříve žila logika v [AdminReservationsScreen]; přesun do repozitáře odděluje UI od DB.
  /// [previousState] a [recordName] připraví volající (obrazovka) kvůli i18n a mapování polí.
  static Future<void> softDeleteReservationWithLinkedTasks({
    required String tenantId,
    required String? userId,
    required String reservationId,
    required Map<String, dynamic> previousState,
    required String recordName,
  }) async {
    final deletedAt = DateTime.now().toUtc().toIso8601String();

    await SupabaseService.safeFrom('reservations', tenantId)
        .update({'deleted_at': deletedAt})
        .eq('id', reservationId);

    await AuditLogService.logEnterprise(
      tenantId: tenantId,
      userId: userId,
      actionType: 'SOFT_DELETE',
      tableName: 'reservations',
      recordId: reservationId,
      recordName: recordName,
      previousState: previousState,
      triggeredBy: AuditTriggeredBy.manual,
    );

    try {
      final tasksRes = await SupabaseService.safeFrom('tasks', tenantId)
          .select('id')
          .eq('reservation_id', reservationId)
          .isFilter('deleted_at', null);
      final taskList = tasksRes as List<dynamic>?;
      if (taskList != null && taskList.isNotEmpty) {
        for (final t in taskList) {
          final taskId = (t is Map ? t['id'] : null)?.toString();
          if (taskId == null || taskId.isEmpty) continue;
          await SupabaseService.safeFrom('tasks', tenantId)
              .update({'deleted_at': deletedAt})
              .eq('id', taskId);
          await AuditLogService.logEnterprise(
            tenantId: tenantId,
            userId: userId,
            actionType: 'SOFT_DELETE_CASCADE',
            tableName: 'tasks',
            recordId: taskId,
            triggeredBy: AuditTriggeredBy.cascade,
            extra: {'triggered_by': 'reservation', 'reservation_id': reservationId},
          );
        }
      }
    } catch (e, st) {
      AppLogger.error('AdminReservationsRepository: kaskádové soft-delete úkolů při mazání rezervace selhalo', e, st);
    }
  }

  /// Pomocná: sestaví zobrazované jméno záznamu pro audit při mazání rezervace.
  static String auditRecordNameForReservation({
    required String reservationId,
    String? guestName,
  }) {
    final shortId = reservationId.length >= 8 ? reservationId.substring(0, 8) : reservationId;
    return guestName?.trim().isNotEmpty == true
        ? guestName!.trim()
        : 'super_admin.audit_log_reservation_fallback'.tr(namedArgs: {'id': shortId});
  }

  /// Aktualizuje stav rezervace (např. při přetažení v Kanbanu).
  static Future<void> updateReservationStatus({
    required String tenantId,
    required String reservationId,
    required String newStatus,
  }) async {
    await SupabaseService.safeFrom('reservations', tenantId)
        .update({'status': newStatus})
        .eq('id', reservationId);
  }
}
