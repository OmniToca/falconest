import 'package:falconest/core/models/automation/tenant_message_log_row.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Repozitář pro čtení audit logu (`tenant_message_log`).
///
/// PROČ: UI by neměla řešit query detaily ani multi-tenant filtry. Repozitář
/// poskytuje jednoduché metody pro načtení vybraného subsetu logů.
class AutomationLogRepository {
  AutomationLogRepository._();

  /// Načte posledních [limit] log z DB pro daný tenant.
  ///
  /// Řazení: nejnovější nahoře podle `sent_at DESC`.
  static Future<List<TenantMessageLogRow>> fetchRecent({
    required String tenantId,
    int limit = 100,
  }) async {
    if (tenantId.isEmpty) return [];

    final res = await SupabaseService.safeFrom('tenant_message_log', tenantId)
        .select('''
          id,
          tenant_id,
          queue_id,
          sent_at,
          channel,
          external_api_id,
          status,
          unit_price,
          recipient_masked,
          content_snapshot,
          error_details,
          created_at,
          direction,
          inbound_text,
          metadata
        ''')
        // PROČ: `metadata` (JSONB) – např. `num_segments` u SMS z Twilio pro zobrazení v historii.
        .order('sent_at', ascending: false)
        .limit(limit);

    return (res as List)
        .map((e) => TenantMessageLogRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Zprávy z `tenant_message_log` vázané na rezervaci přes frontu automatizací.
  ///
  /// PROČ: `queue_id` odkazuje na `automation_message_queue`; u rezervací platí
  /// `entity_type = 'reservation'` a `entity_id` = id rezervace. Inbound záznamy bez `queue_id`
  /// se zde nezobrazují (nemají vazbu na frontu).
  static Future<List<TenantMessageLogRow>> fetchForReservation({
    required String tenantId,
    required String reservationId,
  }) async {
    if (tenantId.isEmpty || reservationId.isEmpty) return [];

    final queueRes = await SupabaseService.safeFrom(
      'automation_message_queue',
      tenantId,
    )
        .select('id')
        .eq('entity_id', reservationId)
        .eq('entity_type', 'reservation');

    final queueIds = (queueRes as List)
        .map((e) => (e as Map)['id'] as String?)
        .whereType<String>()
        .toList()
        .toSet()
        .toList();

    if (queueIds.isEmpty) return [];

    const selectCols = '''
          id,
          tenant_id,
          queue_id,
          sent_at,
          channel,
          external_api_id,
          status,
          unit_price,
          recipient_masked,
          content_snapshot,
          error_details,
          created_at,
          direction,
          inbound_text,
          metadata
        ''';

    final List<TenantMessageLogRow> all = [];
    const int chunk = 80;
    for (var i = 0; i < queueIds.length; i += chunk) {
      final end = (i + chunk < queueIds.length) ? i + chunk : queueIds.length;
      final batch = queueIds.sublist(i, end);
      final logRes = await SupabaseService.safeFrom('tenant_message_log', tenantId)
          .select(selectCols)
          .inFilter('queue_id', batch)
          .order('sent_at', ascending: true);
      final rows = (logRes as List)
          .map(
            (e) =>
                TenantMessageLogRow.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      all.addAll(rows);
    }

    all.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return all;
  }
}

