/// Web implementace WorkerSyncService – no-op, ŽÁDNÝ import Isaru.
///
/// Web je vždy online, lokální Isar ani sync nejsou potřeba.
/// Kompiluje se pro dart:html – nesmí obsahovat isar ani .g.dart.
class WorkerSyncService {
  WorkerSyncService._();

  static Future<void> syncTasksFromSupabase(String workerId, String tenantId) async {}

  static Future<void> pushPendingUpdates(String tenantId) async {}
}
