/// Mobilní implementace MutationQueueService – výhradně Drift (SQLite).
///
/// Isar odstraněn – nestabilní na iOS. Provider vrací DriftMutationQueueService.
/// MutationQueueService.instance deleguje na registrovanou instanci (nastavenou providerem).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/offline/drift_mutation_queue_service.dart';
import 'package:falconest/core/offline/mutation_queue_interface.dart';

/// Globální instance – nastaví provider při prvním read. Používá se z CashWalletRepository atd.
MutationQueueServiceInterface? _mutationQueueInstance;

/// Nastaví instanci pro MutationQueueService.instance (volá provider).
void setMutationQueueInstance(MutationQueueServiceInterface? impl) {
  _mutationQueueInstance = impl;
}

/// Třída pro zpětnou kompatibilitu – CashWalletRepository.instance.enqueueMutation atd.
class MutationQueueService implements MutationQueueServiceInterface {
  MutationQueueService._();

  /// Vrací registrovanou Drift implementaci. Musí být již načten mutationQueueServiceProvider.
  static MutationQueueServiceInterface get instance {
    final i = _mutationQueueInstance;
    if (i == null) {
      throw StateError(
        'MutationQueueService není inicializován. Zajisti, že mutationQueueServiceProvider byl načten (např. SyncStatusIcon).',
      );
    }
    return i;
  }

  @override
  Future<void> enqueueMutation({
    required String table,
    required String action,
    required Map<String, dynamic> payload,
    String? recordId,
  }) =>
      instance.enqueueMutation(table: table, action: action, payload: payload, recordId: recordId);

  @override
  Future<void> processQueue() => instance.processQueue();

  @override
  Future<int> getPendingCount() => instance.getPendingCount();

  /// Rozpozná síťovou chybu – používá se z CashWalletRepository.
  static bool isNetworkError(Object e) {
    final type = e.runtimeType.toString();
    if (type.contains('SocketException')) return true;
    if (type.contains('TimeoutException')) return true;
    if (type.contains('ClientException')) return true;
    if (type.contains('HandshakeException')) return true;
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('network') ||
        msg.contains('timeout')) {
      return true;
    }
    return false;
  }
}

/// Provider pro frontu mutací – Drift (SQLite), Isar odstraněn.
final mutationQueueServiceProvider = Provider<MutationQueueServiceInterface>((ref) {
  final taskRepo = ref.watch(driftTaskRepositoryProvider);
  final service = DriftMutationQueueService(
    ref.watch(driftPendingMutationRepositoryProvider),
    taskRepo,
  );
  setMutationQueueInstance(service);
  return service;
});
