import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/offline/mutation_queue_interface.dart';
import 'package:falconest/core/offline/offline_web_exception.dart';
import 'package:falconest/core/offline/pending_mutation_list_item.dart';

/// Web implementace MutationQueueService – bez lokální Drift fronty.
///
/// PROČ: Web nemá offline-first úložiště jako mobil; při výpadku sítě nesmí být
/// [enqueueMutation] tichý no-op (ztráta dat). Volající musí chytit [OfflineWebException]
/// a upozornit uživatele (viz admin úkoly + [TransientI18nSnackHost]).
class MutationQueueService implements MutationQueueServiceInterface {
  MutationQueueService._();

  static final MutationQueueService instance = MutationQueueService._();

  /// Záměrný hard-fail na webu: zabraňuje tiché ztrátě dat v no-op frontě tím, že uživatele
  /// okamžitě přesměruje na hlášku „bez internetu nelze uložit“ (catch v providerech).
  @override
  Future<void> enqueueMutation({
    required String table,
    required String action,
    required Map<String, dynamic> payload,
    String? recordId,
  }) async {
    throw OfflineWebException(
      'Web: offline mutation queue unavailable (table=$table, action=$action)',
    );
  }

  /// Na webu prázdná fronta – nic k odeslání.
  @override
  Future<void> processQueue() async {}

  /// Na webu vždy false – web je online.
  static bool isNetworkError(Object e) => false;

  /// Na webu vždy 0 – lokální fronta neexistuje.
  @override
  Future<int> getPendingCount() async => 0;

  @override
  Future<List<PendingMutationListItem>> getPendingMutations() async => const [];
}

final mutationQueueServiceProvider =
    Provider<MutationQueueServiceInterface>((ref) {
  return MutationQueueService.instance;
});
