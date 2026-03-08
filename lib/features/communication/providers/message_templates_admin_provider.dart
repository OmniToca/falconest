import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/communication/models/message_template_row.dart';
import 'package:falconest/features/communication/repositories/message_templates_repository.dart';

/// Provider načítající seznam šablon zpráv pro aktuálního tenanta.
///
/// Používá se na Admin obrazovce Komunikace. Po create/update/delete
/// voláme ref.invalidate(messageTemplatesAdminProvider) pro refresh.
final messageTemplatesAdminProvider =
    FutureProvider<List<MessageTemplateRow>>((ref) async {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return [];

  return MessageTemplatesRepository.fetchAll(tenantId);
});

/// Notifier pro CRUD operace – po úspěchu invaliduje messageTemplatesAdminProvider.
class MessageTemplatesAdminNotifier extends StateNotifier<AsyncValue<void>> {
  MessageTemplatesAdminNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> create({
    required String name,
    required String body,
    String? triggerContext,
    String? languageCode,
    int orderIndex = 0,
  }) async {
    state = const AsyncValue.loading();
    final tenantId = _ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      state = AsyncValue.error(
        StateError('communication.error_no_tenant'),
        StackTrace.current,
      );
      return;
    }
    try {
      await MessageTemplatesRepository.createTemplate(
        tenantId,
        name: name,
        body: body,
        triggerContext: triggerContext,
        languageCode: languageCode,
        orderIndex: orderIndex,
      );
      _ref.invalidate(messageTemplatesAdminProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> update(MessageTemplateRow template) async {
    state = const AsyncValue.loading();
    final tenantId = _ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      state = AsyncValue.error(
        StateError('communication.error_no_tenant'),
        StackTrace.current,
      );
      return;
    }
    try {
      await MessageTemplatesRepository.updateTemplate(tenantId, template);
      _ref.invalidate(messageTemplatesAdminProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete(String templateId) async {
    state = const AsyncValue.loading();
    final tenantId = _ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      state = AsyncValue.error(
        StateError('communication.error_no_tenant'),
        StackTrace.current,
      );
      return;
    }
    try {
      await MessageTemplatesRepository.deleteTemplate(tenantId, templateId);
      _ref.invalidate(messageTemplatesAdminProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final messageTemplatesAdminNotifierProvider =
    StateNotifierProvider<MessageTemplatesAdminNotifier, AsyncValue<void>>(
  (ref) => MessageTemplatesAdminNotifier(ref),
);
