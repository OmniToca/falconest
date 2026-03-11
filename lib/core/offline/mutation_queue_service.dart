/// Podmíněný export MutationQueueService a mutationQueueServiceProvider.
///
/// Na webu (dart:html) → no-op, žádný Isar.
/// Na mobilu (dart:io) → plná implementace s PendingMutationLocal.
library;
export 'mutation_queue_service_web.dart'
    if (dart.library.io) 'mutation_queue_service_mobile.dart';
