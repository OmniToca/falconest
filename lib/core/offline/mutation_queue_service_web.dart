import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web implementace MutationQueueService – no-op, ŽÁDNÝ import Isaru.
///
/// Web je vždy online, lokální fronta mutací není potřeba.
class MutationQueueService {
  MutationQueueService._();

  static final MutationQueueService instance = MutationQueueService._();

  /// Na webu nic neukládá – vždy voláme Supabase přímo.
  Future<void> enqueueMutation({
    required String table,
    required String action,
    required Map<String, dynamic> payload,
    String? recordId,
  }) async {}

  /// Na webu prázdná fronta – nic k odeslání.
  Future<void> processQueue() async {}

  /// Na webu vždy false – web je online.
  static bool isNetworkError(Object e) => false;

  /// Na webu vždy 0 – lokální fronta neexistuje.
  Future<int> getPendingCount() async => 0;
}

final mutationQueueServiceProvider = Provider<MutationQueueService>((ref) {
  return MutationQueueService.instance;
});
