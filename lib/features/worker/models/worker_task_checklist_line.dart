/// Jedna položka checklistu pro Worker UI (bez závislosti na Drift – sdílené s web stubem).
///
/// PROČ: [workerTaskChecklistProvider] na webu vrací prázdný seznam; na mobilu mapujeme z řádků SQLite.
class WorkerTaskChecklistLine {
  const WorkerTaskChecklistLine({
    required this.driftRowId,
    required this.supabaseItemId,
    required this.title,
    required this.isPhotoRequired,
    required this.isCompleted,
    this.photoUrl,
    this.localPhotoPath,
  });

  final int driftRowId;
  final String? supabaseItemId;
  final String title;
  final bool isPhotoRequired;
  final bool isCompleted;
  final String? photoUrl;
  /// Lokální stub nebo cesta k souboru – neposílá se jako `photo_url` na server.
  final String? localPhotoPath;
}

/// Vrací true, pokud úkol smí být dokončen z pohledu checklistu (žádný řádek / vše hotovo + fotky).
///
/// PROČ: Zpětná kompatibilita – prázdný seznam = úkol bez checklistu; jinak striktně všechny body a povinné fotky.
bool workerTaskChecklistAllowsCompletion(List<WorkerTaskChecklistLine> items) {
  if (items.isEmpty) return true;
  for (final i in items) {
    if (!i.isCompleted) return false;
    if (i.isPhotoRequired) {
      final u = i.photoUrl?.trim() ?? '';
      if (u.isNotEmpty) continue;
      final lp = i.localPhotoPath?.trim() ?? '';
      // PROČ: Offline-first – stačí lokální soubor ve frontě uploadu; prázdný řetězec = chybí příloha.
      // Staré demo stuby už neuznáváme – worker musí pořídit reálnou fotku.
      if (lp.isEmpty || lp.startsWith('stub_photo_path_')) return false;
    }
  }
  return true;
}
