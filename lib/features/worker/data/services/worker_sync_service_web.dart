/// Web implementace WorkerSyncService – no-op, ŽÁDNÝ import Isaru.
///
/// Web je vždy online, lokální Isar ani sync nejsou potřeba.
/// Kompiluje se pro dart:html – nesmí obsahovat isar ani .g.dart.
class WorkerSyncService {
  WorkerSyncService._();

  static Future<void> syncTasksFromSupabase(
    String workerId,
    String tenantId, {
    void Function(String)? onSyncError,
  }) async {}

  static Future<void> pushPendingUpdates(
    String tenantId, {
    void Function(String)? onSyncError,
  }) async {}

  static Future<void> pushPendingReservationUpdates(
    String tenantId, {
    void Function(String)? onSyncError,
  }) async {}

  /// Na webu vždy 0 – není Isar.
  static Future<int> getPendingSyncCount(String tenantId) async => 0;
}
