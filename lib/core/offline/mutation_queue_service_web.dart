import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/offline/mutation_queue_interface.dart';

/// Web implementace MutationQueueService – no-op, ŽÁDNÝ import Isaru.
///
/// Web je vždy online, lokální fronta mutací není potřeba.
class MutationQueueService implements MutationQueueServiceInterface {
  MutationQueueService._();

  static final MutationQueueService instance = MutationQueueService._();

  /// Na webu nic neukládá – vždy voláme Supabase přímo.
  @override
  Future<void> enqueueMutation({
    required String table,
    required String action,
    required Map<String, dynamic> payload,
    String? recordId,
  }) async {}

  /// Na webu prázdná fronta – nic k odeslání.
  @override
  Future<void> processQueue() async {}

  /// Na webu vždy false – web je online.
  static bool isNetworkError(Object e) => false;

  /// Na webu vždy 0 – lokální fronta neexistuje.
  @override
  Future<int> getPendingCount() async => 0;
}

final mutationQueueServiceProvider =
    Provider<MutationQueueServiceInterface>((ref) {
  return MutationQueueService.instance;
});
