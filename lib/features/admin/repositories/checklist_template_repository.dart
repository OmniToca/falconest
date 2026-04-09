import 'package:uuid/uuid.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/tasks/models/checklists/checklist_template_item_model.dart';
import 'package:falconest/features/tasks/models/checklists/checklist_template_model.dart';

/// Řádek draftu pro uložení šablony (bez Freezed – mutovatelný editor).
///
/// PROČ: [localKey] stabilně identifikuje řádek v ReorderableListView; [serverId]
/// je UUID z DB po prvním uložení.
class ChecklistTemplateDraftLine {
  ChecklistTemplateDraftLine({
    String? localKey,
    this.serverId,
    required this.title,
    this.isPhotoRequired = false,
    required this.sortOrder,
  }) : localKey = localKey ?? const Uuid().v4();

  final String localKey;
  final String? serverId;
  final String title;
  final bool isPhotoRequired;
  final int sortOrder;

  ChecklistTemplateDraftLine copyWith({
    String? serverId,
    String? title,
    bool? isPhotoRequired,
    int? sortOrder,
  }) {
    return ChecklistTemplateDraftLine(
      localKey: localKey,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      isPhotoRequired: isPhotoRequired ?? this.isPhotoRequired,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// CRUD nad `checklist_templates` a `checklist_template_items` (Supabase + RLS).
///
/// PROČ: Admin UI potřebuje seznam, smazání a atomické nahrazení položek při uložení
/// (Postgres transakce z klienta nejsou – nejdřív update hlavičky, pak delete+insert řádků).
class ChecklistTemplateRepository {
  ChecklistTemplateRepository._();

  static final ChecklistTemplateRepository instance = ChecklistTemplateRepository._();

  /// Načte šablony tenanta seřazené podle názvu.
  Future<List<ChecklistTemplateModel>> listTemplates(String tenantId) async {
    if (tenantId.isEmpty) return [];
    final res = await SupabaseService.safeFrom('checklist_templates', tenantId)
        .select('id, tenant_id, name, description, is_active, created_at, updated_at')
        .order('name', ascending: true);
    final list = res as List<dynamic>;
    return list
        .map((e) => ChecklistTemplateModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Načte položky šablony podle pořadí.
  Future<List<ChecklistTemplateItemModel>> listTemplateItems(
    String tenantId,
    String templateId,
  ) async {
    if (tenantId.isEmpty || templateId.isEmpty) return [];
    final res = await SupabaseService.safeFrom('checklist_template_items', tenantId)
        .select('id, tenant_id, template_id, title, is_photo_required, sort_order, created_at, updated_at')
        .eq('template_id', templateId)
        .order('sort_order', ascending: true);
    final list = res as List<dynamic>;
    return list
        .map((e) => ChecklistTemplateItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Vytvoří instanci checklistu u úkolu a **zmrazí** body šablony do `task_checklist_items`.
  ///
  /// PROČ: Worker pracuje s neměnnou kopií; šablona se může později měnit bez vlivu na rozjeté úkoly.
  /// Po INSERTu hlavičky načteme řádky z `checklist_template_items` a jedním voláním `insert(rows)`
  /// je přeneseme (ne N× samostatný INSERT – šetří round-tripsy a zátěž DB).
  Future<void> instantiateChecklistForTask({
    required String tenantId,
    required String taskId,
    required String templateId,
  }) async {
    if (tenantId.isEmpty || taskId.isEmpty || templateId.isEmpty) return;

    // PROČ: Obrana proti zneužití – UI filtruje aktivní šablony, ale API musí být konzistentní.
    final tplRow = await SupabaseService.safeFrom('checklist_templates', tenantId)
        .select('id, is_active')
        .eq('id', templateId)
        .maybeSingle();
    if (tplRow == null) return;
    final isActive = tplRow['is_active'] == true;
    if (!isActive) return;

    final inserted = await SupabaseService.safeFrom('task_checklists', tenantId).insert({
      'task_id': taskId,
      'template_id': templateId,
    }).select('id').single();
    final taskChecklistId = (inserted['id'] as String?)?.trim() ?? '';
    if (taskChecklistId.isEmpty) {
      throw StateError('ChecklistTemplateRepository: INSERT task_checklists nevrátil id');
    }

    final items = await listTemplateItems(tenantId, templateId);
    if (items.isEmpty) return;

    final rows = <Map<String, dynamic>>[];
    for (final it in items) {
      rows.add(
        SupabaseService.safeInsertPayload(tenantId, {
          'task_checklist_id': taskChecklistId,
          'title': it.title,
          'is_photo_required': it.isPhotoRequired,
          'sort_order': it.sortOrder,
        }),
      );
    }
    await SupabaseService.safeFrom('task_checklist_items', tenantId).insert(rows);
  }

  /// Smaže šablonu (položky CASCADE z migrace).
  Future<void> deleteTemplate(String tenantId, String templateId) async {
    if (tenantId.isEmpty || templateId.isEmpty) return;
    await SupabaseService.safeFrom('checklist_templates', tenantId).delete().eq('id', templateId);
  }

  /// Uloží hlavičku a **nahradí** všechny položky – konzistentní stav pro editor.
  ///
  /// Vrací id šablony (nové nebo existující).
  Future<String> saveTemplateFull({
    required String tenantId,
    String? templateId,
    required String name,
    required String? description,
    required bool isActive,
    required List<ChecklistTemplateDraftLine> lines,
  }) async {
    if (tenantId.isEmpty) {
      throw Exception('tenant_id je prázdný');
    }
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('NAME_EMPTY');
    }

    String effectiveTemplateId;

    if (templateId == null || templateId.isEmpty) {
      final inserted = await SupabaseService.safeFrom('checklist_templates', tenantId)
          .insert({
            'name': trimmedName,
            'description': description?.trim().isEmpty == true ? null : description?.trim(),
            'is_active': isActive,
          })
          .select('id')
          .single();
      effectiveTemplateId = (inserted['id'] as String?)?.trim() ?? '';
      if (effectiveTemplateId.isEmpty) {
        throw Exception('INSERT checklist_templates nevrátil id');
      }
    } else {
      effectiveTemplateId = templateId;
      await SupabaseService.safeFrom('checklist_templates', tenantId).update({
        'name': trimmedName,
        'description': description?.trim().isEmpty == true ? null : description?.trim(),
        'is_active': isActive,
      }).eq('id', effectiveTemplateId);
    }

    await SupabaseService.safeFrom('checklist_template_items', tenantId)
        .delete()
        .eq('template_id', effectiveTemplateId);

    if (lines.isNotEmpty) {
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final t = line.title.trim();
        if (t.isEmpty) continue;
        rows.add(
          SupabaseService.safeInsertPayload(tenantId, {
            'template_id': effectiveTemplateId,
            'title': t,
            'is_photo_required': line.isPhotoRequired,
            'sort_order': i,
          }),
        );
      }
      if (rows.isNotEmpty) {
        await SupabaseService.safeFrom('checklist_template_items', tenantId).insert(rows);
      }
    }

    return effectiveTemplateId;
  }
}
