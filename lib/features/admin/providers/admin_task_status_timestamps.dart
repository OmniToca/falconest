/// Time Tracking: doplnění `started_at` / `completed_at` při admin změně statusu úkolu.
///
/// PROČ: Worker app zapisuje razítka při zahájení/dokončení. Admin Kanban a editační dialog
/// dříve měnily jen `status` → v DB zůstávala NULL a reporty / efektivita / fakturace měly díry.
/// Tato funkce sjednocuje pravidla pro [AdminTasksNotifier.updateTaskStatus] i [updateTaskInAdmin].
library;

/// Normalizace statusu na kanonické systémové hodnoty (shodné s Kanban / worker).
String normalizeAdminTaskSystemStatus(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'pending';
  final s = raw.trim().toLowerCase();
  if (s == 'pending' || s == 'draft' || s == 'návrh') return 'pending';
  if (s == 'assigned' || s == 'new' || s == 'nový' || s == 'zadáno') {
    return 'assigned';
  }
  if (s == 'in_progress' || s == 'probíhá') return 'in_progress';
  if (s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno') {
    return 'completed';
  }
  if (s == 'problém' || s == 'problem' || s == 'issue') return 'problem';
  return s;
}

/// Mutuje [updateFields]: doplní / vynuluje časová razítka podle přechodu statusu.
///
/// Pravidla:
/// - → `in_progress` a `started_at` je null → nastav `started_at` = teď (UTC).
/// - → `completed` → nastav `completed_at` = teď; pokud `started_at` chybí, nastav i ten.
/// - → `assigned` / `pending` („Zadáno“ / návrh) → vynuluj obě razítka.
///
/// Explicitní klíče už v [updateFields] (např. z dialogu) se nepřepisují.
/// Při stejném statusu razítka nemění (kromě opravného doplnění u `completed` bez `completed_at`).
void applyAdminTaskStatusTimestampsToUpdate(
  Map<String, dynamic> updateFields, {
  String? previousStatus,
  DateTime? currentStartedAt,
  DateTime? currentCompletedAt,
}) {
  if (!updateFields.containsKey('status')) return;

  final newStatus = normalizeAdminTaskSystemStatus(
    updateFields['status']?.toString(),
  );
  final oldStatus = normalizeAdminTaskSystemStatus(previousStatus);
  final nowIso = DateTime.now().toUtc().toIso8601String();

  if (newStatus == oldStatus) {
    // Oprava děr: úkol už je completed, ale razítka chybí (starší data / dřívější bug).
    if (newStatus == 'completed') {
      if (!updateFields.containsKey('completed_at') &&
          currentCompletedAt == null) {
        updateFields['completed_at'] = nowIso;
      }
      if (!updateFields.containsKey('started_at') && currentStartedAt == null) {
        updateFields['started_at'] = nowIso;
      }
    }
    return;
  }

  if (newStatus == 'in_progress') {
    if (!updateFields.containsKey('started_at') && currentStartedAt == null) {
      updateFields['started_at'] = nowIso;
    }
    return;
  }

  if (newStatus == 'completed') {
    if (!updateFields.containsKey('completed_at')) {
      updateFields['completed_at'] = nowIso;
    }
    // Fallback: dokončení bez zahájení → started_at = completed_at (stejný okamžik).
    if (!updateFields.containsKey('started_at') && currentStartedAt == null) {
      updateFields['started_at'] =
          updateFields['completed_at']?.toString() ?? nowIso;
    }
    return;
  }

  // Zadáno / návrh – návrat do stavu před zahájením práce.
  if (newStatus == 'assigned' || newStatus == 'pending') {
    if (!updateFields.containsKey('started_at')) {
      updateFields['started_at'] = null;
    }
    if (!updateFields.containsKey('completed_at')) {
      updateFields['completed_at'] = null;
    }
  }
}
