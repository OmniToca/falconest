import 'package:falconest/core/services/supabase_service.dart';

import 'package:falconest/core/models/automation/automation_enums.dart';
import 'package:falconest/core/models/automation/automation_rule_row.dart';

/// Repozitář pro CRUD nad tabulkou `automation_rules`.
///
/// PROČ: Uchováváme logiku přístupu k Supabase v jedné vrstvě, aby UI a
/// Riverpod provider zůstaly čisté a jednotné (Clean Architecture).
class AutomationRulesRepository {
  AutomationRulesRepository._();

  /// Načte všechny aktivní pravidla pro daný tenant.
  ///
  /// POZNÁMKA: Řešíme i listing pro UI. RLS + frontend firewall (safeFrom)
  /// zaručují multi-tenant izolaci.
  static Future<List<AutomationRuleRow>> fetchAll(String tenantId) async {
    if (tenantId.isEmpty) return [];

    final res = await SupabaseService.safeFrom('automation_rules', tenantId)
        .select('id, tenant_id, name, is_active, trigger_event, offset_minutes, channel, template_id, target_entity, staff_profile_id, quiet_hours_start, quiet_hours_end, created_at, updated_at')
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => AutomationRuleRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Vytvoří nové pravidlo a vrátí vložený záznam.
  static Future<AutomationRuleRow> createRule({
    required String tenantId,
    required AutomationRuleRow rule,
  }) async {
    if (tenantId.isEmpty) {
      throw StateError('automation_rules.error_no_tenant');
    }
    if (rule.id.trim().isEmpty) {
      // `id` je v DB default, ale v UI/DTO ho někdy budujeme bez id.
      // Proto pro insert použijeme jen mapu bez `id` – DB vygeneruje UUID.
      final map = rule.toMap()..remove('id');
      final res = await SupabaseService.safeFrom('automation_rules', tenantId)
          .insert(map)
          .select()
          .single();
      return AutomationRuleRow.fromJson(Map<String, dynamic>.from(res as Map));
    }

    final res = await SupabaseService.safeFrom('automation_rules', tenantId)
        .insert(rule.toMap())
        .select()
        .single();
    return AutomationRuleRow.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Aktualizuje existující pravidlo v `automation_rules` podle `updatedRule.id`.
  ///
  /// PROČ: Editace musí provést čistý UPDATE bez přepisu `created_at` a bez INSERT logiky
  /// pro nové UUID; tenant izolace zůstává přes `safeFrom` + RLS.
  static Future<AutomationRuleRow> updateRule({
    required String tenantId,
    required AutomationRuleRow updatedRule,
  }) async {
    if (tenantId.isEmpty || updatedRule.id.trim().isEmpty) {
      throw StateError('automation_rules.error_no_tenant');
    }

    final qs = updatedRule.quietHoursStart?.trim();
    final qe = updatedRule.quietHoursEnd?.trim();

    final map = <String, dynamic>{
      'name': updatedRule.name,
      'is_active': updatedRule.isActive,
      'trigger_event': updatedRule.triggerEvent,
      'offset_minutes': updatedRule.offsetMinutes,
      'channel': updatedRule.channel.toDb(),
      'template_id': updatedRule.templateId,
      'target_entity': updatedRule.targetEntity,
      'staff_profile_id': updatedRule.staffProfileId != null &&
              updatedRule.staffProfileId!.trim().isNotEmpty
          ? updatedRule.staffProfileId!.trim()
          : null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'quiet_hours_start': (qs == null || qs.isEmpty) ? null : qs,
      'quiet_hours_end': (qe == null || qe.isEmpty) ? null : qe,
    };

    final res = await SupabaseService.safeFrom('automation_rules', tenantId)
        .update(map)
        .eq('id', updatedRule.id)
        .select()
        .single();

    return AutomationRuleRow.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Zapne/vypne pravidlo (`is_active`).
  static Future<void> setRuleActive({
    required String tenantId,
    required String ruleId,
    required bool isActive,
  }) async {
    if (tenantId.isEmpty || ruleId.isEmpty) return;

    await SupabaseService.safeFrom('automation_rules', tenantId)
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', ruleId);
  }

  /// Smaže pravidlo z DB.
  static Future<void> deleteRule({
    required String tenantId,
    required String ruleId,
  }) async {
    if (tenantId.isEmpty || ruleId.isEmpty) return;

    await SupabaseService.safeFrom('automation_rules', tenantId)
        .delete()
        .eq('id', ruleId);
  }
}

