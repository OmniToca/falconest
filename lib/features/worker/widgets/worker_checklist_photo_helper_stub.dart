/// Web: žádný přístup k souborům – focení checklistu není k dispozici.
Future<String?> captureChecklistPhotoForWorker({
  required String taskId,
  required String tenantId,
}) async {
  return null;
}

/// Web: kopie na disk neexistuje – API pro kompilaci sdílených importů.
Future<String?> copyChecklistPhotoToOfflineDirectory(String taskId, dynamic file) async {
  return null;
}
