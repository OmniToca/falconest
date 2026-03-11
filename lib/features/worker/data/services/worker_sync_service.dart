/// Podmíněný export WorkerSyncService.
///
/// Na webu (dart.library.html) → no-op, žádný Isar.
/// Na mobilu (dart.library.io) → plná Isar offline-first synchronizace.
library;
export 'worker_sync_service_web.dart'
    if (dart.library.io) 'worker_sync_service_mobile.dart';
