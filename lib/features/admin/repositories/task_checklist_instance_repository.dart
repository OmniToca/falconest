import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/repositories/checklist_template_repository.dart';
import 'package:falconest/features/tasks/models/checklists/task_checklist_item_model.dart';

/// Načítání a zápis **instance** checklistu u úkolu (`task_checklists` + `task_checklist_items`).
///
/// PROČ: Manažerské úpravy v admin dialogu mění pouze zkopírované řádky u úkolu, nikdy
/// `checklist_templates` / `checklist_template_items` – ty řeší [ChecklistTemplateRepository].

/// Hlavička instance + položky pro jeden úkol (max. jedna hlavička díky UNIQUE(task_id)).
class TaskChecklistInstanceData {
  const TaskChecklistInstanceData({
    required this.taskChecklistId,
    required this.items,
  });

  final String taskChecklistId;
  final List<TaskChecklistItemModel> items;
}

class TaskChecklistInstanceRepository {
  TaskChecklistInstanceRepository._();

  static final TaskChecklistInstanceRepository instance = TaskChecklistInstanceRepository._();

  /// Načte instanci checklistu pro [taskId] a položky seřazené podle [sort_order].
  ///
  /// PROČ: Bez hlavičky `task_checklists` vrací null (úkol nemá zmrazený checklist).
  Future<TaskChecklistInstanceData?> fetchForTask(String tenantId, String taskId) async {
    if (tenantId.isEmpty || taskId.isEmpty) return null;
    final header = await SupabaseService.safeFrom('task_checklists', tenantId)
        .select('id')
        .eq('task_id', taskId)
        .maybeSingle();
    if (header == null) return null;
    final tcId = (header['id'] as String?)?.trim() ?? '';
    if (tcId.isEmpty) return null;

    final raw = await SupabaseService.safeFrom('task_checklist_items', tenantId)
        .select()
        .eq('task_checklist_id', tcId)
        .order('sort_order', ascending: true);
    final list = raw as List<dynamic>;
    final items = list
        .map((e) => TaskChecklistItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return TaskChecklistInstanceData(taskChecklistId: tcId, items: items);
  }

  /// Uloží draft řádků do Supabase – pouze tabulka `task_checklist_items` (+ případně INSERT hlavičky).
  ///
  /// [initialItemIds] = ID řádků načtených při otevření dialogu; ty, které v [lines] chybí, se smažou.
  /// [taskChecklistId] pokud null a [lines] neprázdné, vytvoří se řádek v `task_checklists`.
  ///
  /// PROČ: Neaktualizujeme dokončení workerem (`is_completed`, `photo_url`, …) – ty zůstávají v DB,
  /// pokud v [lines] nepředáváme jejich změnu; při UPDATE posíláme jen text, pořadí a příznak fotky u položky.
  ///
  /// Vrací aktuální [task_checklists.id] (po případném vytvoření hlavičky).
  Future<String?> saveDraft({
    required String tenantId,
    required String taskId,
    required String? taskChecklistId,
    required Set<String> initialItemIds,
    required List<ChecklistTemplateDraftLine> lines,
  }) async {
    if (tenantId.isEmpty || taskId.isEmpty) return null;

    final effective = lines.where((l) => l.title.trim().isNotEmpty).toList();
    var tcId = taskChecklistId?.trim() ?? '';

    // Všechny řádky prázdné → smaž dříve načtené instance z DB, hlavička zůstane (jedna na úkol).
    if (effective.isEmpty) {
      if (initialItemIds.isNotEmpty) {
        final safeItems = SupabaseService.safeFrom('task_checklist_items', tenantId);
        for (final id in initialItemIds) {
          if (id.isEmpty) continue;
          await safeItems.delete().eq('id', id);
        }
      }
      return tcId.isEmpty ? null : tcId;
    }

    if (tcId.isEmpty) {
      final inserted = await SupabaseService.safeFrom('task_checklists', tenantId)
          .insert({
            'task_id': taskId,
          })
          .select('id')
          .single();
      tcId = (inserted['id'] as String?)?.trim() ?? '';
      if (tcId.isEmpty) {
        throw StateError('task_checklists INSERT nevrátil id');
      }
    }

    final safeItems = SupabaseService.safeFrom('task_checklist_items', tenantId);
    final keptIds = <String>{};
    for (var i = 0; i < effective.length; i++) {
      final line = effective[i];
      final title = line.title.trim();
      final sid = line.serverId?.trim();
      if (sid != null && sid.isNotEmpty) {
        keptIds.add(sid);
        await safeItems.update({
          'title': title,
          'is_photo_required': line.isPhotoRequired,
          'sort_order': i,
        }).eq('id', sid);
      } else {
        await safeItems.insert(
          SupabaseService.safeInsertPayload(tenantId, {
            'task_checklist_id': tcId,
            'title': title,
            'is_photo_required': line.isPhotoRequired,
            'sort_order': i,
          }),
        );
      }
    }

    final toRemove = initialItemIds.difference(keptIds);
    for (final id in toRemove) {
      if (id.isEmpty) continue;
      await safeItems.delete().eq('id', id);
    }
    return tcId;
  }
}
