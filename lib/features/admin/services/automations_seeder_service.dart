import 'package:falconest/core/services/supabase_service.dart';

/// Seeder for FÁZE 5: výchozí „zlaté“ šablony a pravidla pro Automations.
///
/// PROČ:
/// - aby agentury nezačínaly s prázdným seznamem v modulu Automatizace,
/// - přestože ještě nemají vyplněné svoje vlastní šablony,
/// - proto seeded rules vkládáme se `is_active = false` (manažer si je může jen zkontrolovat a zapnout).
class AutomationsSeederService {
  AutomationsSeederService._();

  /// Seed zautomatizuje vytvoření 4 golden šablon a 4 pravidel.
  ///
  /// Idempotence:
  /// - šablony: hledáme podle deterministického `key` a znovu je nevkládáme,
  /// - pravidla: hledáme podle kombinace `(trigger_event, offset_minutes, channel, template_id, target_entity)`.
  ///   Pokud pravidlo už existuje, vložení přeskočíme.
  static Future<void> seedDefaultAutomations(String tenantId) async {
    final tid = tenantId.trim();
    if (tid.isEmpty) return;

    // 1) Zlaté šablony (tenant_message_templates) – obsah jen v `translations` jsonb.
    const templates = [
      _SeedTemplate(
        key: 'auto_self_checkin_d2_whatsapp',
        name: 'Self Check-in (D-2)',
        channel: 'whatsapp',
        triggerContext: 'check_in',
        orderIndex: 0,
        translationsEnBody:
            'Good day {guest_name}, we are looking forward to hosting you! Your apartment {keybox} is ready. The keybox code is: {keybox}. Address: ...',
      ),
      _SeedTemplate(
        key: 'auto_review_day2_sms',
        name: 'Review request (Day-2)',
        channel: 'sms',
        triggerContext: 'check_in',
        orderIndex: 1,
        translationsEnBody:
            'Good day {guest_name}, we hope your first night went well. Is everything alright? If you need anything, we are here for you.',
      ),
      _SeedTemplate(
        key: 'auto_checkout_instructions_d1_whatsapp',
        name: 'Checkout instructions (D-1)',
        channel: 'whatsapp',
        triggerContext: 'check_out',
        orderIndex: 2,
        translationsEnBody:
            'Good day {guest_name}, reminder: check-out is tomorrow at 10:00. Please leave the keys in the keybox and close the windows. Safe travels!',
      ),
      _SeedTemplate(
        key: 'auto_staff_briefing_taskstart_email',
        name: 'Morning briefing (staff)',
        channel: 'email',
        emailSubject: 'FalcoNest – briefing for today',
        triggerContext: null,
        orderIndex: 3,
        translationsEnBody:
            'New information for your tasks today. Please check the details in the FalcoNest app.',
      ),
    ];

    // 2) Zlatá pravidla (automation_rules)
    const rules = [
      _SeedRule(
        name: 'Golden rule: Self Check-in (D-2)',
        triggerEvent: 'reservation_check_in',
        offsetMinutes: -2880,
        channel: 'whatsapp',
        targetEntity: 'guest',
        templateKey: 'auto_self_checkin_d2_whatsapp',
      ),
      _SeedRule(
        name: 'Golden rule: Review request (Day-2)',
        triggerEvent: 'reservation_check_in',
        offsetMinutes: 1440,
        channel: 'sms',
        targetEntity: 'guest',
        templateKey: 'auto_review_day2_sms',
      ),
      _SeedRule(
        name: 'Golden rule: Checkout instructions (D-1)',
        triggerEvent: 'reservation_check_out',
        offsetMinutes: -720,
        channel: 'whatsapp',
        targetEntity: 'guest',
        templateKey: 'auto_checkout_instructions_d1_whatsapp',
      ),
      _SeedRule(
        name: 'Golden rule: Morning briefing (staff)',
        triggerEvent: 'task_start',
        offsetMinutes: -120,
        channel: 'email',
        targetEntity: 'guest',
        templateKey: 'auto_staff_briefing_taskstart_email',
      ),
    ];

    // KROK 1: Získat (nebo vytvořit) template IDs.
    final templateIdByKey = <String, String>{};
    for (final t in templates) {
      final existing = await SupabaseService.safeFrom('tenant_message_templates', tid)
          .select('id')
          .eq('key', t.key)
          .isFilter('deleted_at', null)
          .maybeSingle();

      final existingId = (existing?['id'] as String?)?.trim();
      if (existingId != null && existingId.isNotEmpty) {
        templateIdByKey[t.key] = existingId;
        continue;
      }

      final insertPayload = <String, dynamic>{
        'key': t.key,
        'name': t.name,
        'channel': t.channel,
        'translations': {
          'en': {'body': t.translationsEnBody},
        },
        'trigger_context': t.triggerContext,
        'order_index': t.orderIndex,
      };
      if (t.emailSubject != null && t.emailSubject!.trim().isNotEmpty) {
        insertPayload['email_subject'] = t.emailSubject!.trim();
      }

      final res = await SupabaseService.safeFrom('tenant_message_templates', tid)
          .insert(insertPayload)
          .select('id')
          .single();

      final id = (res['id'] as String?)?.trim();
      if (id != null && id.isNotEmpty) {
        templateIdByKey[t.key] = id;
      }
    }

    // KROK 2: Získat (nebo vytvořit) automation_rules.
    for (final r in rules) {
      final templateId = templateIdByKey[r.templateKey];
      if (templateId == null || templateId.isEmpty) continue;

      final existingRule = await SupabaseService.safeFrom('automation_rules', tid)
          .select('id')
          .eq('trigger_event', r.triggerEvent)
          .eq('offset_minutes', r.offsetMinutes)
          .eq('channel', r.channel)
          .eq('target_entity', r.targetEntity)
          .eq('template_id', templateId)
          .maybeSingle();

      final existingId = (existingRule?['id'] as String?)?.trim();
      if (existingId != null && existingId.isNotEmpty) continue;

      final payload = <String, dynamic>{
        'name': r.name,
        'is_active': false,
        'trigger_event': r.triggerEvent,
        'offset_minutes': r.offsetMinutes,
        'channel': r.channel,
        'template_id': templateId,
        'target_entity': r.targetEntity,
      };

      await SupabaseService.safeFrom('automation_rules', tid).insert(payload);
    }
  }
}

class _SeedTemplate {
  const _SeedTemplate({
    required this.key,
    required this.name,
    required this.channel,
    required this.triggerContext,
    required this.orderIndex,
    required this.translationsEnBody,
    this.emailSubject,
  });

  final String key;
  final String name;
  final String channel;
  final String? triggerContext;
  final int orderIndex;
  final String translationsEnBody;
  final String? emailSubject;
}

class _SeedRule {
  const _SeedRule({
    required this.name,
    required this.triggerEvent,
    required this.offsetMinutes,
    required this.channel,
    required this.targetEntity,
    required this.templateKey,
  });

  final String name;
  final String triggerEvent;
  final int offsetMinutes;
  final String channel;
  final String targetEntity;
  final String templateKey;
}
