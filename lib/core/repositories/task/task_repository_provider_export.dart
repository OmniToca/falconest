/// Podmíněný export taskRepositoryProvider.
///
/// Na webu → TaskRepositoryWeb (Supabase).
/// Na mobilu → DriftTaskRepository (SQLite, 100 % offline stabilita na iOS).
export 'task_repository_provider_stub.dart'
    if (dart.library.html) 'task_repository_provider_web.dart'
    if (dart.library.io) 'task_repository_provider_mobile.dart';
