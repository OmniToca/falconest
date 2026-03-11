/// Mobilní implementace – šablony z Drift (SQLite). Isar odstraněn.
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/database/models/message_template_local.dart';
import 'package:falconest/core/database/drift/database_provider.dart';

final messageTemplatesForWorkerProvider =
    FutureProvider.family<List<MessageTemplateLocal>, String>((ref, tenantId) async {
  if (tenantId.isEmpty) return [];

  try {
    final repo = ref.watch(driftMessageTemplateRepositoryProvider);
    final list = await repo.getAllByTenantId(tenantId);

    // Filtrování: zobrazit šablony s trigger_context null/prázdný nebo 'transfer'.
    final filtered = list.where((t) {
      final ctx = t.triggerContext?.trim().toLowerCase();
      return ctx == null || ctx.isEmpty || ctx == 'transfer';
    }).toList();

    filtered.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return filtered;
  } catch (_) {
    return [];
  }
});
