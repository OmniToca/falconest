import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/repositories/checklist_template_repository.dart';
import 'package:falconest/features/tasks/models/checklists/checklist_template_model.dart';

/// Stav draftu editoru šablony checklistu (název, popis, položky).
///
/// PROČ: Oddělení od [ChecklistTemplateModel], protože editor pracuje s lokálními
/// klíči řádků a rozpracovaným textem před uložením.
class ChecklistTemplateEditorState {
  const ChecklistTemplateEditorState({
    this.templateId,
    this.name = '',
    this.description = '',
    this.isActive = true,
    this.items = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessageKey,
  });

  final String? templateId;
  final String name;
  final String description;
  final bool isActive;
  final List<ChecklistTemplateDraftLine> items;
  final bool isLoading;
  final bool isSaving;

  /// i18n klíč chyby (nebo null) – žádný hardcoded text v UI.
  final String? errorMessageKey;

  ChecklistTemplateEditorState copyWith({
    String? templateId,
    String? name,
    String? description,
    bool? isActive,
    List<ChecklistTemplateDraftLine>? items,
    bool? isLoading,
    bool? isSaving,
    String? errorMessageKey,
    bool clearError = false,
  }) {
    return ChecklistTemplateEditorState(
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessageKey: clearError ? null : (errorMessageKey ?? this.errorMessageKey),
    );
  }
}

/// Draft editoru šablony – [templateId] null = nová šablona.
final checklistTemplateEditorProvider = StateNotifierProvider.family<
    ChecklistTemplateEditorNotifier,
    ChecklistTemplateEditorState,
    String?>(
  (ref, templateId) => ChecklistTemplateEditorNotifier(ref, templateId),
);

/// Notifier držící draft a operace přidání / mazání / změna pořadí.
///
/// PROČ: [reorderItems] používá standardní algoritmus „remove + insert“ po úpravě
/// indexu při přesunu dolů (ReorderableListView dodává +1 index).
class ChecklistTemplateEditorNotifier extends StateNotifier<ChecklistTemplateEditorState> {
  ChecklistTemplateEditorNotifier(this._ref, this._templateId)
      : super(const ChecklistTemplateEditorState()) {
    if ((_templateId ?? '').isNotEmpty) {
      _load();
    } else {
      state = const ChecklistTemplateEditorState(
        items: [],
      );
    }
  }

  final Ref _ref;
  final String? _templateId;

  ChecklistTemplateRepository get _repo => ChecklistTemplateRepository.instance;

  Future<void> _load() async {
    final tid = _ref.read(authNotifierProvider).tenantIdForData;
    if (tid == null || tid.isEmpty || _templateId == null || _templateId.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessageKey: 'checklists.error_no_tenant');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final templates = await _repo.listTemplates(tid);
      ChecklistTemplateModel? header;
      for (final t in templates) {
        if (t.id == _templateId) {
          header = t;
          break;
        }
      }
      if (header == null) {
        state = state.copyWith(isLoading: false, errorMessageKey: 'checklists.error_template_not_found');
        return;
      }
      final rows = await _repo.listTemplateItems(tid, header.id);
      final drafts = <ChecklistTemplateDraftLine>[];
      for (final r in rows) {
        drafts.add(
          ChecklistTemplateDraftLine(
            localKey: r.id,
            serverId: r.id,
            title: r.title,
            isPhotoRequired: r.isPhotoRequired,
            sortOrder: r.sortOrder,
          ),
        );
      }
      state = ChecklistTemplateEditorState(
        templateId: header.id,
        name: header.name,
        description: header.description ?? '',
        isActive: header.isActive,
        items: drafts,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessageKey: 'checklists.error_load_failed');
    }
  }

  void setName(String v) => state = state.copyWith(name: v);

  void setDescription(String v) => state = state.copyWith(description: v);

  void setIsActive(bool v) => state = state.copyWith(isActive: v);

  /// Přidá prázdný bod na konec seznamu.
  void addItem() {
    final nextOrder = state.items.length;
    final next = List<ChecklistTemplateDraftLine>.from(state.items)
      ..add(
        ChecklistTemplateDraftLine(
          title: '',
          sortOrder: nextOrder,
        ),
      );
    state = state.copyWith(items: next);
  }

  void removeItemAt(int index) {
    if (index < 0 || index >= state.items.length) return;
    final next = List<ChecklistTemplateDraftLine>.from(state.items)..removeAt(index);
    for (var i = 0; i < next.length; i++) {
      next[i] = next[i].copyWith(sortOrder: i);
    }
    state = state.copyWith(items: next);
  }

  void updateItemTitle(int index, String title) {
    if (index < 0 || index >= state.items.length) return;
    final next = List<ChecklistTemplateDraftLine>.from(state.items);
    next[index] = next[index].copyWith(title: title);
    state = state.copyWith(items: next);
  }

  void updateItemPhotoRequired(int index, bool value) {
    if (index < 0 || index >= state.items.length) return;
    final next = List<ChecklistTemplateDraftLine>.from(state.items);
    next[index] = next[index].copyWith(isPhotoRequired: value);
    state = state.copyWith(items: next);
  }

  /// Změna pořadí při přetahování v [ReorderableListView].
  ///
  /// PROČ: Flutter při přesunu dolů posílá [newIndex] o 1 vyšší než cílové místo –
  /// musíme ubrat 1 (dokumentace ReorderableListView).
  void reorderItems(int oldIndex, int newIndex) {
    final list = List<ChecklistTemplateDraftLine>.from(state.items);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    for (var i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(sortOrder: i);
    }
    state = state.copyWith(items: list);
  }

  /// Uložení na server – hlavička + kompletní nahrazení položek v repozitáři.
  Future<bool> save() async {
    final tenantId = _ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) {
      state = state.copyWith(errorMessageKey: 'checklists.error_no_tenant');
      return false;
    }
    final name = state.name.trim();
    if (name.isEmpty) {
      state = state.copyWith(errorMessageKey: 'checklists.error_name_required');
      return false;
    }
    final nonEmptyLines = state.items.where((e) => e.title.trim().isNotEmpty).toList();
    if (nonEmptyLines.isEmpty) {
      state = state.copyWith(errorMessageKey: 'checklists.error_items_required');
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repo.saveTemplateFull(
        tenantId: tenantId,
        templateId: state.templateId,
        name: name,
        description: state.description.trim().isEmpty ? null : state.description.trim(),
        isActive: state.isActive,
        lines: nonEmptyLines,
      );
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('NAME_EMPTY')) {
        state = state.copyWith(isSaving: false, errorMessageKey: 'checklists.error_name_required');
      } else {
        state = state.copyWith(isSaving: false, errorMessageKey: 'checklists.error_save_failed');
      }
      return false;
    }
  }
}
