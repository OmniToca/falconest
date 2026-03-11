/// Podmíněný export implementace ITaskRepository.
///
/// Na webu (dart.library.html) → TaskRepositoryWeb (Supabase, žádný Isar).
/// Na mobilu (dart.library.io) → TaskRepositoryMobile (Isar offline-first).
/// Fallback → stub (UnsupportedError).
library;
export 'task_repository_stub.dart'
    if (dart.library.html) 'task_repository_web.dart'
    if (dart.library.io) 'task_repository_mobile.dart';
