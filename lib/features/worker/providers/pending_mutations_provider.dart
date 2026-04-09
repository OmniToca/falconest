import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/offline/pending_mutation_list_item.dart';

/// Reaktivní seznam položek lokální fronty mutací (Drift), filtrovaný podle aktivního tenanta.
///
/// PROČ: Worker vidí jen mutace, které patří jeho tenantovi (`tenant_id` v payloadu);
/// položky bez tenant_id v payloadu zobrazíme také (historické / speciální enqueue),
/// aby nic „nezmizelo“ bez vysvětlení – admin fronta může později zpřesnit pravidla.
/// Na webu lokální fronta neexistuje → prázdný stream.
final pendingMutationsProvider =
    StreamProvider<List<PendingMutationListItem>>((ref) async* {
  if (kIsWeb) {
    yield const [];
    return;
  }

  final repo = ref.watch(driftPendingMutationRepositoryProvider);

  await for (final rows in repo.watchAllOrderedByCreatedAt()) {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    final items = rows.map(PendingMutationListItem.fromRow).where((m) {
      if (tenantId == null || tenantId.isEmpty) return true;
      final rowTenant = m.tenantIdFromPayload;
      if (rowTenant == null) return true;
      return rowTenant == tenantId;
    }).toList();
    yield items;
  }
});
