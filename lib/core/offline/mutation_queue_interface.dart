/// Rozhraní pro službu fronty offline mutací.
///
/// Implementují ho Isar MutationQueueService i DriftMutationQueueService.
/// Umožňuje přepojení providera na SQLite bez změny konzumentů.
abstract interface class MutationQueueServiceInterface {
  Future<void> enqueueMutation({
    required String table,
    required String action,
    required Map<String, dynamic> payload,
    String? recordId,
  });

  Future<void> processQueue();

  Future<int> getPendingCount();
}
