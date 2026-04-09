/// Mobilní implementace – šablony z Drift (SQLite). Isar odstraněn.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/database/models/message_template_local.dart';
import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';

final messageTemplatesForWorkerProvider =
    FutureProvider.family<List<MessageTemplateLocal>, String>((ref, tenantId) async {
  if (tenantId.isEmpty) return [];

  try {
    final repo = ref.watch(driftMessageTemplateRepositoryProvider);
    final list = await repo.getAllByTenantId(tenantId);
    // Vracíme VŠECHNY šablony; filtrování podle trigger_context probíhá až v UI (Smart Template Selector).
    list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return list;
  } catch (e, st) {
    AppLogger.error('messageTemplatesForWorkerProvider: načtení šablon z Drift selhalo', e, st);
    return [];
  }
});
