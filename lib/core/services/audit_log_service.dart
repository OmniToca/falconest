import 'package:falconest/core/audit/enterprise_audit_payload.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Služba pro zápis záznamů do [audit_logs] – audit akcí uživatelů (aktivace modulů, změny).
class AuditLogService {
  AuditLogService._();

  /// Vloží záznam do public.audit_logs.
  /// [tenantId] a [userId] by měly odpovídat přihlášenému kontextu (RLS to kontroluje).
  static Future<void> log({
    required String? tenantId,
    required String? userId,
    required String actionType,
    String? tableName,
    String? recordId,
    Map<String, dynamic>? details,
  }) async {
    try {
      await SupabaseService.client.from('audit_logs').insert({
        'tenant_id': tenantId,
        'user_id': userId,
        'action_type': actionType,
        'table_name': tableName,
        'record_id': recordId,
        'details': details,
      });
    } catch (e, st) {
      assert(() {
        // ignore: avoid_print
        print('[AuditLogService] log failed: $e');
        // ignore: avoid_print
        print(st);
        return true;
      }());
      rethrow;
    }
  }

  /// Zápis do audit_logs s plným Enterprise kontextem do JSONB details.
  ///
  /// PROČ: Každá mutační akce má do logu zapsat record_name, actor_snapshot (jméno a e-mail
  /// v době akce), previous_state/new_state pro Undo a diff, client_info (Web/iOS/Android),
  /// triggered_by (manual/cascade/system) a volitelný reason. Služba sama dohledá aktuálního
  /// actora a doplní client_info; zbytek předá volající. Zpětně kompatibilní – [extra] sloučí
  /// do details (module_key, apartment_id atd.).
  static Future<void> logEnterprise({
    required String? tenantId,
    required String? userId,
    required String actionType,
    String? tableName,
    String? recordId,
    String? recordName,
    Map<String, dynamic>? previousState,
    Map<String, dynamic>? newState,
    String? triggeredBy,
    String? reason,
    Map<String, dynamic>? extra,
  }) async {
    final actorSnapshot = await EnterpriseAuditPayload.getCurrentActorSnapshot();
    final details = EnterpriseAuditPayload.buildDetails(
      recordName: recordName,
      actorSnapshot: actorSnapshot,
      previousState: previousState,
      newState: newState,
      triggeredBy: triggeredBy ?? AuditTriggeredBy.manual,
      reason: reason,
      extra: extra,
    );
    await log(
      tenantId: tenantId,
      userId: userId,
      actionType: actionType,
      tableName: tableName,
      recordId: recordId,
      details: details.isNotEmpty ? details : null,
    );
  }
}
