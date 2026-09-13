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
    Object? driftRepos,
    void Function()? onSmartMergeApplied,
  }) async {
    // Web je vždy online – Drift nepotřebuje.
  }

  static Future<void> pushPendingUpdates(
    String tenantId, {
    void Function(String)? onSyncError,
    Object? driftRepos,
    void Function()? onSmartMergeApplied,
  }) async {}

  static Future<void> pushPendingReservationUpdates(
    String tenantId, {
    void Function(String)? onSyncError,
    Object? driftRepos,
  }) async {}

  /// Na webu vždy 0 – není lokální databáze.
  static Future<int> getPendingSyncCount(String tenantId, {Object? driftRepos}) async => 0;

  /// Web je vždy online a zapisuje přímo do Supabase – no-op.
  static Future<void> flushPendingUpdatesBestEffort(
    String tenantId, {
    void Function(String)? onSyncError,
    Object? driftRepos,
    Duration timeout = const Duration(seconds: 3),
  }) async {}
}
