import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/automation/automation_rule_row.dart';

import 'automation_rules_repository.dart';

/// Provider pro seznam pravidel automatizací pro aktuálního tenanta.
///
/// Build načítá data (čtení). Notifier poskytuje metody pro mutace (zápis),
/// které po úspěchu invalidují/reloadují tento provider.
final automationRulesProvider = AsyncNotifierProvider<AutomationRulesNotifier, List<AutomationRuleRow>>(
  AutomationRulesNotifier.new,
);

class AutomationRulesNotifier extends AsyncNotifier<List<AutomationRuleRow>> {
  @override
  Future<List<AutomationRuleRow>> build() async {
    final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return [];
    return AutomationRulesRepository.fetchAll(tenantId);
  }

  /// Vytvoří nové pravidlo do `automation_rules`.
  ///
  /// PROČ AsyncNotifier: máme jeden životní cyklus a po mutaci můžeme
  /// okamžitě přepočítat state listu pro UI.
  Future<void> createRule(AutomationRuleRow rule) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('automation_rules.error_no_tenant');
    }

    state = const AsyncValue.loading();
    try {
      // Bezpečně vnutí tenant_id z kontextu tenanta, i když DTO přijde bez něj.
      final normalized = rule.copyWith(tenantId: tenantId);
      await AutomationRulesRepository.createRule(tenantId: tenantId, rule: normalized);

      // Po úspěchu přenačteme aktuální seznam.
      final items = await AutomationRulesRepository.fetchAll(tenantId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Uloží změny existujícího pravidla (`UPDATE` podle `updatedRule.id`).
  ///
  /// PROČ: Stejný vzor jako [createRule] – po zápisu přenačteme seznam, aby UI mělo
  /// konzistentní data z DB (včetně `updated_at`).
  Future<void> updateRule(AutomationRuleRow updatedRule) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('automation_rules.error_no_tenant');
    }
    if (updatedRule.id.trim().isEmpty) return;

    state = const AsyncValue.loading();
    try {
      final normalized = updatedRule.copyWith(tenantId: tenantId);
      await AutomationRulesRepository.updateRule(tenantId: tenantId, updatedRule: normalized);

      final items = await AutomationRulesRepository.fetchAll(tenantId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Rychlé zapnutí/vypnutí pravidla.
  Future<void> toggleRuleActive(String id, bool isActive) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('automation_rules.error_no_tenant');
    }
    if (id.trim().isEmpty) return;

    state = const AsyncValue.loading();
    try {
      await AutomationRulesRepository.setRuleActive(
        tenantId: tenantId,
        ruleId: id,
        isActive: isActive,
      );
      final items = await AutomationRulesRepository.fetchAll(tenantId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Smaže pravidlo.
  Future<void> deleteRule(String id) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('automation_rules.error_no_tenant');
    }
    if (id.trim().isEmpty) return;

    state = const AsyncValue.loading();
    try {
      await AutomationRulesRepository.deleteRule(tenantId: tenantId, ruleId: id);
      final items = await AutomationRulesRepository.fetchAll(tenantId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

