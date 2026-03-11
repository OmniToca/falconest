// Služba pro synchronizaci iCal odkazů (Airbnb, Booking) s rezervacemi.
// Webová Flutter aplikace nemůže přímo stahovat .ics kvůli CORS. Edge Function
// `ical-fetch` stáhne obsah a vrátí JSON události. Tato služba volá Edge Function,
// vyfiltruje duplicity podle external_uid (idempotence) a vloží nové rezervace
// ve stavu 'new' pro ruční projití dispečerem.
// STRICT: Nevoláme generateSmartTasks() – rezervace se jen tiše uloží do DB.

import 'package:flutter/foundation.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/id_generator.dart';

/// Model jednoho iCal zdroje z apartment_ical_sources.
class IcalSourceRow {
  const IcalSourceRow({
    required this.id,
    required this.icalUrl,
    required this.sourceLabel,
    this.lastSyncedAt,
  });

  final String id;
  final String icalUrl;
  final String sourceLabel;
  final DateTime? lastSyncedAt;

  factory IcalSourceRow.fromJson(Map<String, dynamic> json) {
    return IcalSourceRow(
      id: json['id'] as String? ?? '',
      icalUrl: json['ical_url'] as String? ?? '',
      sourceLabel: json['source_label'] as String? ?? '',
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.tryParse(json['last_synced_at'].toString())
          : null,
    );
  }
}

/// Výsledek synchronizace jednoho iCal zdroje.
class IcalSyncResult {
  const IcalSyncResult({
    required this.insertedCount,
    required this.skippedDuplicates,
    this.error,
  });

  final int insertedCount;
  final int skippedDuplicates;
  final String? error;
}

/// Služba pro CRUD iCal zdrojů a spouštění synchronizace.
class IcalSyncService {
  IcalSyncService._();
  static final IcalSyncService instance = IcalSyncService._();

  final _client = SupabaseService.client;

  /// Načte uložené iCal zdroje pro daný apartmán.
  Future<List<IcalSourceRow>> getSources(String apartmentId) async {
    final res = await _client
        .from('apartment_ical_sources')
        .select('id, ical_url, source_label, last_synced_at')
        .eq('apartment_id', apartmentId)
        .order('source_label');
    return (res as List)
        .map((e) => IcalSourceRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Přidá nový iCal zdroj pro apartmán. Vyžaduje tenantId pro RLS.
  Future<IcalSourceRow> addSource({
    required String apartmentId,
    required String tenantId,
    required String url,
    required String label,
  }) async {
    final res = await SupabaseService.safeFrom('apartment_ical_sources', tenantId).insert({
      'apartment_id': apartmentId,
      'ical_url': url.trim(),
      'source_label': label.trim().isEmpty ? 'iCal' : label.trim(),
    }).select('id, ical_url, source_label, last_synced_at').single();
    return IcalSourceRow.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Odstraní iCal zdroj.
  Future<void> removeSource(String sourceId) async {
    await _client.from('apartment_ical_sources').delete().eq('id', sourceId);
  }

  /// Synchronizuje jeden iCal URL: volá Edge Function, filtruje duplicity, vkládá nové rezervace.
  /// Vrací počet vložených a počet přeskočených duplicit.
  Future<IcalSyncResult> syncIcalUrl({
    required String apartmentId,
    required String tenantId,
    required String icalUrl,
  }) async {
    try {
      // 1) Volání Edge Function
      final res = await _client.functions.invoke(
        'ical-fetch',
        body: {'ical_url': icalUrl.trim()},
      );
      if (res.status != 200) {
        return IcalSyncResult(
          insertedCount: 0,
          skippedDuplicates: 0,
          error: res.data is Map && (res.data as Map).containsKey('error')
              ? (res.data as Map)['error']?.toString()
              : 'ical-fetch vrátila status ${res.status}',
        );
      }

      final data = res.data;
      if (data is! Map) {
        return const IcalSyncResult(
          insertedCount: 0,
          skippedDuplicates: 0,
          error: 'Neplatná odpověď Edge Function',
        );
      }

      final rawError = data['error'];
      if (rawError != null && rawError.toString().isNotEmpty) {
        return IcalSyncResult(
          insertedCount: 0,
          skippedDuplicates: 0,
          error: rawError.toString(),
        );
      }

      final eventsRaw = data['events'];
      if (eventsRaw is! List || eventsRaw.isEmpty) {
        return const IcalSyncResult(
          insertedCount: 0,
          skippedDuplicates: 0,
        );
      }

      final events = <Map<String, dynamic>>[];
      for (final e in eventsRaw) {
        if (e is Map) {
          final uid = (e['uid'] as String?)?.trim();
          if (uid == null || uid.isEmpty) continue;
          events.add(Map<String, dynamic>.from(e));
        }
      }

      if (events.isEmpty) {
        return const IcalSyncResult(
          insertedCount: 0,
          skippedDuplicates: 0,
        );
      }

      final uids = events.map((e) => (e['uid'] as String?)?.trim()).whereType<String>().toSet().toList();
      if (uids.isEmpty) {
        return const IcalSyncResult(
          insertedCount: 0,
          skippedDuplicates: 0,
        );
      }

      // 2) Najdi existující external_uid v DB pro tohoto tenanta
      final existingRes = await SupabaseService.safeFrom('reservations', tenantId)
          .select('external_uid')
          .inFilter('external_uid', uids)
          .not('external_uid', 'is', null);
      final existingUids = (existingRes as List)
          .map((r) => (r as Map)['external_uid']?.toString())
          .whereType<String>()
          .toSet();

      // 3) Filtruj jen nové eventy (idempotence)
      final newEvents = events.where((e) {
        final uid = (e['uid'] as String?)?.trim();
        return uid != null && uid.isNotEmpty && !existingUids.contains(uid);
      }).toList();
      final skippedDuplicates = events.length - newEvents.length;

      if (newEvents.isEmpty) {
        return IcalSyncResult(
          insertedCount: 0,
          skippedDuplicates: skippedDuplicates,
        );
      }

      // 4) Vlož nové rezervace
      final toInsert = <Map<String, dynamic>>[];
      for (final ev in newEvents) {
        final uid = (ev['uid'] as String?)?.trim() ?? '';
        final summary = (ev['summary'] as String?)?.trim() ?? '';
        final dtstart = ev['dtstart']?.toString();
        final dtend = ev['dtend']?.toString();
        if (dtstart == null || dtstart.isEmpty || dtend == null || dtend.isEmpty) continue;

        final startDt = DateTime.tryParse(dtstart);
        final endDt = DateTime.tryParse(dtend);
        if (startDt == null || endDt == null || !endDt.isAfter(startDt)) continue;

        final startDate = startDt.toUtc();
        final endDate = endDt.toUtc();
        final startDateStr = startDate.toIso8601String().substring(0, 10);
        final endDateStr = endDate.toIso8601String().substring(0, 10);

        final arrivalTime = DateTime.utc(
          startDate.year,
          startDate.month,
          startDate.day,
          startDate.hour,
          startDate.minute,
          startDate.second,
        ).toIso8601String();
        final departureTime = DateTime.utc(
          endDate.year,
          endDate.month,
          endDate.day,
          endDate.hour,
          endDate.minute,
          endDate.second,
        ).toIso8601String();

        toInsert.add({
          'tenant_id': tenantId,
          'apartment_id': apartmentId,
          'reference_number': generateReservationRef(),
          'start_date': startDateStr,
          'end_date': endDateStr,
          'status': 'new',
          'guest_name': summary.isEmpty ? null : summary,
          'guest_phone': null,
          'guest_adults': 0,
          'guest_children': 0,
          'arrival_time': arrivalTime,
          'departure_time': departureTime,
          'external_uid': uid,
        });
      }

      if (toInsert.isEmpty) {
        return IcalSyncResult(
          insertedCount: 0,
          skippedDuplicates: skippedDuplicates,
        );
      }

      await SupabaseService.safeFrom('reservations', tenantId).insert(toInsert);
      return IcalSyncResult(
        insertedCount: toInsert.length,
        skippedDuplicates: skippedDuplicates,
      );
    } catch (e, st) {
      debugPrint('ical_sync_service syncIcalUrl error: $e\n$st');
      return IcalSyncResult(
        insertedCount: 0,
        skippedDuplicates: 0,
        error: e.toString(),
      );
    }
  }

  /// Aktualizuje last_synced_at u zdroje po úspěšném syncu.
  Future<void> updateLastSyncedAt(String sourceId) async {
    await _client
        .from('apartment_ical_sources')
        .update({'last_synced_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', sourceId);
  }
}
