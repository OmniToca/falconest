import 'dart:convert';

import 'package:falconest/core/models/automation/automation_enums.dart';
import 'package:falconest/core/models/automation/automation_queue_row.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Repozitář pro CRUD operace nad tabulkou `automation_message_queue`.
///
/// PROČ: V UI nechceme řešit Supabase query logiku. Repozitář poskytuje
/// jednoduché metody pro čtení a mutace (cancel/edit) s respektováním
/// multi-tenancy izolace (`safeFrom`).
class AutomationQueueRepository {
  AutomationQueueRepository._();

  /// Načte pouze pending zprávy pro daný tenant.
  static Future<List<AutomationQueueRow>> fetchPending(String tenantId) async {
    if (tenantId.isEmpty) return [];

    final res = await SupabaseService.safeFrom('automation_message_queue', tenantId)
        .select('''
          id,
          tenant_id,
          rule_id,
          entity_id,
          entity_type,
          scheduled_for,
          status,
          channel,
          recipient_contact,
          editable_payload,
          attempt_count,
          last_error,
          created_at,
          updated_at
        ''')
        .eq('status', 'pending')
        .order('scheduled_for', ascending: true)
        .limit(200);

    return (res as List)
        .map((e) => AutomationQueueRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Zruší položku fronty (`status = cancelled`).
  static Future<void> cancelMessage({
    required String tenantId,
    required String id,
  }) async {
    if (tenantId.isEmpty || id.isEmpty) return;

    await SupabaseService.safeFrom('automation_message_queue', tenantId)
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  /// PROČ: Okamžité odeslání – posuneme `scheduled_for` na „teď“, aby ji vzal worker.
  static Future<void> scheduleSendNow({
    required String tenantId,
    required String id,
  }) async {
    if (tenantId.isEmpty || id.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await SupabaseService.safeFrom('automation_message_queue', tenantId).update({
      'scheduled_for': now,
      'updated_at': now,
    }).eq('id', id);
  }

  /// PROČ: Proběhne Edge `automation-dispatch` (bez čekání na CRON).
  ///
  /// **401 Invalid JWT (zejména Flutter Web):** Supabase Edge ověřuje JWT před spuštěním funkce.
  /// Interní stav [FunctionsClient] může mít zastaralý `Authorization`; explicitně posíláme
  /// aktuální `Bearer` z [Session.accessToken], aby gateway přijal požadavek.
  static Future<void> invokeAutomationDispatch() async {
    final client = SupabaseService.client;
    final session = client.auth.currentSession;
    if (session == null) {
      throw StateError('automation_queue.error_no_session');
    }

    final res = await client.functions.invoke(
      'automation-dispatch',
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
      },
    );
    if (res.status != 200) {
      throw Exception(
        'automation_dispatch_http_${res.status}: ${res.data}',
      );
    }
  }

  /// Ruční zpráva do fronty (`entity_type = adhoc`, `rule_id` NULL).
  static Future<void> insertAdhocMessage({
    required String tenantId,
    required AutomationChannel channel,
    required String recipientContact,
    required String messageText,
    String? emailSubject,
  }) async {
    if (tenantId.isEmpty) {
      throw StateError('automation_queue.error_no_tenant');
    }
    final trimmedRecipient = recipientContact.trim();
    final trimmedText = messageText.trim();
    if (trimmedRecipient.isEmpty || trimmedText.isEmpty) {
      throw StateError('automation_queue.adhoc_validation');
    }

    final payload = <String, dynamic>{
      'text': trimmedText,
      'source': 'adhoc_admin_ui',
    };
    if (channel == AutomationChannel.email &&
        emailSubject != null &&
        emailSubject.trim().isNotEmpty) {
      payload['email_subject'] = emailSubject.trim();
    }

    await SupabaseService.safeFrom('automation_message_queue', tenantId).insert({
      'rule_id': null,
      'entity_id': AutomationQueueRow.kAdhocEntitySentinel,
      'entity_type': 'adhoc',
      'scheduled_for': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending',
      'channel': channel.toDb(),
      'recipient_contact': trimmedRecipient,
      'editable_payload': payload,
      'attempt_count': 0,
    });
  }

  static Map<String, dynamic> _parsePayload(dynamic raw) {
    if (raw == null) return const {};
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (e, st) {
        AppLogger.error('AutomationQueueRepository: jsonDecode editable_payload selhal', e, st);
      }
    }
    return const {};
  }

  /// Aktualizuje `editable_payload` tak, aby UI „vědělo“, co má manažer editovat.
  ///
  /// V UI předáváme pouze plain text. Proto v payloadu zapisujeme klíč `text`.
  /// Pokud už payload obsahuje alternativní klíče (např. `body`), přepíšeme i je,
  /// aby zůstala konzistence.
  static Future<void> updateMessagePayload({
    required String tenantId,
    required String id,
    required String newText,
  }) async {
    if (tenantId.isEmpty || id.isEmpty) return;

    final existing = await SupabaseService.safeFrom('automation_message_queue', tenantId)
        .select('editable_payload')
        .eq('id', id)
        .maybeSingle();

    final rawPayload = existing is Map
        ? (existing as Map)['editable_payload']
        : null;
    final payload = _parsePayload(rawPayload);

    final trimmed = newText.trim();
    final updated = Map<String, dynamic>.from(payload)
      ..['text'] = trimmed;

    if (updated.containsKey('body')) {
      updated['body'] = trimmed;
    }
    if (updated.containsKey('message')) {
      updated['message'] = trimmed;
    }

    await SupabaseService.safeFrom('automation_message_queue', tenantId)
        .update({
          'editable_payload': updated,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }
}

