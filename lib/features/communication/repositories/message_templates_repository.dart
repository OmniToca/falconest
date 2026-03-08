import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/communication/models/message_template_row.dart';

/// Repozitář pro CRUD operace nad šablonami zpráv (tenant_message_templates).
///
/// VŠECHNY dotazy jsou striktně vázány na tenant_id – multi-tenant izolace.
/// Soft delete: místo DELETE se volá UPDATE deleted_at = now().
class MessageTemplatesRepository {
  MessageTemplatesRepository._();

  /// Načte všechny aktivní šablony tenanta (deleted_at IS NULL).
  /// Seřazeno podle order_index, pak language_code, pak name.
  /// Limit 500 jako pojistka proti přetečení paměti u velkých tenantů.
  static Future<List<MessageTemplateRow>> fetchAll(String tenantId) async {
    if (tenantId.isEmpty) return [];

    final res = await SupabaseService.client
        .from('tenant_message_templates')
        .select()
        .eq('tenant_id', tenantId)
        .isFilter('deleted_at', null)
        .order('order_index')
        .order('language_code', ascending: true)
        .order('name')
        .limit(500);

    return (res as List)
        .map((e) => MessageTemplateRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Vytvoří novou šablonu. Klíč se vygeneruje z názvu + časové razítko pro jednoznačnost.
  ///
  /// PROČ: key musí být unikátní v rámci tenanta; slug z názvu + suffix zajišťuje
  /// čitelnost v DB a unikátnost. tenant_id se předává z auth – RLS blokuje inserty jiným.
  static Future<MessageTemplateRow> createTemplate(
    String tenantId, {
    required String name,
    required String body,
    String? triggerContext,
    String? languageCode,
    int orderIndex = 0,
  }) async {
    if (tenantId.isEmpty) {
      throw StateError('communication.error_tenant_required');
    }

    final key = _generateKey(name, triggerContext);

    final map = <String, dynamic>{
      'tenant_id': tenantId,
      'key': key,
      'name': name.trim(),
      'body': body.trim(),
      'channel': 'whatsapp_link',
      'order_index': orderIndex,
    };
    if (triggerContext != null && triggerContext.trim().isNotEmpty) {
      map['trigger_context'] = triggerContext.trim();
    }
    if (languageCode != null && languageCode.trim().isNotEmpty) {
      map['language_code'] = languageCode.trim();
    }

    final res = await SupabaseService.client
        .from('tenant_message_templates')
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
      'body': template.body.trim(),
      'channel': template.channel,
      'order_index': template.orderIndex,
      'trigger_context': template.triggerContext?.trim(),
      'language_code': template.languageCode?.trim(),
    };

    await SupabaseService.client
        .from('tenant_message_templates')
        .update(map)
        .eq('id', template.id)
        .eq('tenant_id', tenantId);
  }

  /// Soft delete – nastaví deleted_at = now(). Záznam zůstane v DB, ale nebude se zobrazovat.
  ///
  /// PROČ: Zachovává historická data, RLS i sync na mobil; Worker nevidí smazané šablony.
  static Future<void> deleteTemplate(String tenantId, String templateId) async {
    if (tenantId.isEmpty || templateId.isEmpty) return;

    await SupabaseService.client
        .from('tenant_message_templates')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', templateId)
        .eq('tenant_id', tenantId);
  }

  /// Vygeneruje unikátní key z názvu a trigger kontextu.
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
