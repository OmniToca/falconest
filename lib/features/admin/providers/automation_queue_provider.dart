import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/automation/automation_enums.dart';
import 'package:falconest/core/models/automation/automation_queue_row.dart';

import 'automation_log_provider.dart';
import 'automation_queue_repository.dart';

/// Provider pro čtení položek „Čekárny“ (queue).
///
/// Načítáme pouze `status = pending`, řazeno od nejbližšího `scheduled_for`.
final automationQueueProvider = AsyncNotifierProvider<AutomationQueueNotifier, List<AutomationQueueRow>>(
  AutomationQueueNotifier.new,
);

class AutomationQueueNotifier extends AsyncNotifier<List<AutomationQueueRow>> {
  @override
  Future<List<AutomationQueueRow>> build() async {
    final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return [];
    return AutomationQueueRepository.fetchPending(tenantId);
  }

  Future<void> cancelMessage(String id) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('automation_queue.error_no_tenant');
    }
    if (id.trim().isEmpty) return;

    state = const AsyncValue.loading();
    try {
      await AutomationQueueRepository.cancelMessage(tenantId: tenantId, id: id);
      final items = await AutomationQueueRepository.fetchPending(tenantId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateMessagePayload(String id, String newText) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('automation_queue.error_no_tenant');
    }
    if (id.trim().isEmpty) return;

    state = const AsyncValue.loading();
    try {
      await AutomationQueueRepository.updateMessagePayload(
        tenantId: tenantId,
        id: id,
        newText: newText,
      );
      final items = await AutomationQueueRepository.fetchPending(tenantId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// PROČ: Posune čas odeslání na „teď“ a hned zavolá Edge dispečink.
  Future<void> sendNow(String id) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('automation_queue.error_no_tenant');
    }
    if (id.trim().isEmpty) return;

    state = const AsyncValue.loading();
    try {
      await AutomationQueueRepository.scheduleSendNow(tenantId: tenantId, id: id);
      await AutomationQueueRepository.invokeAutomationDispatch();
      ref.invalidate(automationLogProvider);
      final items = await AutomationQueueRepository.fetchPending(tenantId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// PROČ: Ruční vložení zprávy do fronty + okamžité zpracování dispečinkem.
  Future<void> insertAdhocMessage({
    required AutomationChannel channel,
    required String recipientContact,
    required String messageText,
    String? emailSubject,
  }) async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('automation_queue.error_no_tenant');
    }

    state = const AsyncValue.loading();
    try {
      await AutomationQueueRepository.insertAdhocMessage(
        tenantId: tenantId,
        channel: channel,
        recipientContact: recipientContact,
        messageText: messageText,
        emailSubject: emailSubject,
      );
      await AutomationQueueRepository.invokeAutomationDispatch();
      ref.invalidate(automationLogProvider);
      final items = await AutomationQueueRepository.fetchPending(tenantId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}


