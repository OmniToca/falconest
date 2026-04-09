import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/communication/models/message_template_row.dart';

/// Repozitář pro CRUD operace nad šablonami zpráv (tenant_message_templates).
///
/// VŠECHNY dotazy jsou striktně vázány na tenant_id – multi-tenant izolace.
/// Frontend Firewall: [SupabaseService.safeFrom] vynutí tenant i pro Super Admina.
/// Soft delete: místo DELETE se volá UPDATE deleted_at = now().
class MessageTemplatesRepository {
  MessageTemplatesRepository._();

  /// Načte všechny aktivní šablony tenanta (deleted_at IS NULL).
  /// Seřazeno podle order_index, pak name.
  static Future<List<MessageTemplateRow>> fetchAll(String tenantId) async {
    if (tenantId.isEmpty) return [];

    final res = await SupabaseService.safeFrom('tenant_message_templates', tenantId)
        .select(
          'id, tenant_id, key, name, channel, email_subject, translations, trigger_context, order_index, created_at, deleted_at',
        )
        .isFilter('deleted_at', null)
        .order('order_index')
        .order('name')
        .limit(500);

    return (res as List)
        .map((e) => MessageTemplateRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Vytvoří novou šablonu. Klíč se vygeneruje z názvu + časové razítko pro jednoznačnost.
  static Future<MessageTemplateRow> createTemplate(
    String tenantId, {
    required String name,
    required String channel,
    String? emailSubject,
    required MessageTemplateTranslations translations,
    String? triggerContext,
    int orderIndex = 0,
  }) async {
    if (tenantId.isEmpty) {
      throw StateError('communication.error_tenant_required');
    }

    final key = _generateKey(name, triggerContext);

    final map = <String, dynamic>{
      'key': key,
      'name': name.trim(),
      'channel': channel.trim().toLowerCase(),
      'translations': translations.toJson(),
      'order_index': orderIndex,
    };
    if (emailSubject != null && emailSubject.trim().isNotEmpty) {
      map['email_subject'] = emailSubject.trim();
    }
    if (triggerContext != null && triggerContext.trim().isNotEmpty) {
      map['trigger_context'] = triggerContext.trim();
    }

    final res = await SupabaseService.safeFrom('tenant_message_templates', tenantId)
        .insert(map)
        .select()
        .single();

    return MessageTemplateRow.fromJson(Map<String, dynamic>.from(res));
  }

  /// Aktualizuje existující šablonu. Kontroluje tenant_id.
  static Future<void> updateTemplate(
    String tenantId,
    MessageTemplateRow template,
  ) async {
    if (tenantId.isEmpty) {
      throw StateError('communication.error_tenant_required');
    }
    if (template.id.isEmpty) {
      throw StateError('communication.error_template_no_id');
    }
    if (template.tenantId != tenantId) {
      throw StateError('communication.error_template_tenant_mismatch');
    }

    final map = <String, dynamic>{
      'key': template.key.trim(),
      'name': template.name.trim(),
      'channel': template.channel,
      'email_subject': template.emailSubject?.trim(),
      'translations': template.translations.toJson(),
      'order_index': template.orderIndex,
      'trigger_context': template.triggerContext?.trim(),
    };

    await SupabaseService.safeFrom('tenant_message_templates', tenantId)
        .update(map)
        .eq('id', template.id);
  }

  /// Soft delete – nastaví deleted_at = now().
  static Future<void> deleteTemplate(String tenantId, String templateId) async {
    if (tenantId.isEmpty || templateId.isEmpty) return;

    await SupabaseService.safeFrom('tenant_message_templates', tenantId).update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', templateId);
  }

  static String _generateKey(String name, String? triggerContext) {
    final base = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s\-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final slug = base.isEmpty ? 'template' : base;
    final ctx = (triggerContext?.trim().isNotEmpty == true)
        ? triggerContext!.trim().toLowerCase()
        : 'general';
    return '${ctx}_${slug}_${DateTime.now().millisecondsSinceEpoch}';
  }
}
