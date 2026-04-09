import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/task_checklist_items_provider.dart';
import 'package:falconest/features/admin/repositories/checklist_template_repository.dart';
import 'package:falconest/features/admin/repositories/task_checklist_instance_repository.dart';

/// Rozbalovací sekce se zmrazeným checklistem úkolu – úpravy jdou jen do `task_checklist_items`.
///
/// PROČ: Oddělený widget kvůli přehlednosti v [admin_tasks_screen]; ukládání volá rodič
/// přes [persistChecklistIfNeeded] při Uložit v dialogu úkolu (ne průběžně).
class TaskChecklistInstanceEditorSection extends ConsumerStatefulWidget {
  const TaskChecklistInstanceEditorSection({
    super.key,
    required this.taskId,
    required this.readOnly,
  });

  final String taskId;
  final bool readOnly;

  @override
  ConsumerState<TaskChecklistInstanceEditorSection> createState() =>
      TaskChecklistInstanceEditorSectionState();
}

class TaskChecklistInstanceEditorSectionState extends ConsumerState<TaskChecklistInstanceEditorSection> {
  bool _draftReady = false;
  String? _taskChecklistId;
  final List<ChecklistTemplateDraftLine> _lines = [];
  final Set<String> _initialItemIds = {};
  final Map<String, bool> _itemCompleted = {};

  void _applySnapshot(TaskChecklistInstanceData? data) {
    _lines.clear();
    _initialItemIds.clear();
    _itemCompleted.clear();
    _taskChecklistId = data?.taskChecklistId;
    if (data != null) {
      for (final m in data.items) {
        _lines.add(
          ChecklistTemplateDraftLine(
            serverId: m.id,
            title: m.title,
            isPhotoRequired: m.isPhotoRequired,
            sortOrder: m.sortOrder,
          ),
        );
        _initialItemIds.add(m.id);
        _itemCompleted[m.id] = m.isCompleted;
      }
    }
  }

  /// Uloží draft do Supabase (pouze instance). Volá rodič z dialogu před uzavřením.
  ///
  /// PROČ: Žádný dotyk `checklist_template_items` – výhradně [TaskChecklistInstanceRepository.saveDraft].
  /// Po zápisu znovu načteme řádky z API, aby lokální [serverId] odpovídaly DB (nové INSERTy).
  Future<void> persistChecklistIfNeeded(String tenantId) async {
    if (widget.readOnly || tenantId.isEmpty) return;
    // PROČ: Uživatel může uložit hlavní formulář dřív, než proběhne postFrame seed – nejdřív sladit draft s API.
    if (!_draftReady) {
      final snap = await ref.read(taskChecklistItemsProvider(widget.taskId).future);
      if (!mounted) return;
      setState(() {
        _draftReady = true;
        _applySnapshot(snap);
      });
    }
    await TaskChecklistInstanceRepository.instance.saveDraft(
      tenantId: tenantId,
      taskId: widget.taskId,
      taskChecklistId: _taskChecklistId,
      initialItemIds: Set<String>.from(_initialItemIds),
      lines: List<ChecklistTemplateDraftLine>.from(_lines),
    );
    ref.invalidate(taskChecklistItemsProvider(widget.taskId));
    final fresh = await ref.read(taskChecklistItemsProvider(widget.taskId).future);
    if (!mounted) return;
    setState(() {
      _applySnapshot(fresh);
    });
  }

  void _addLine() {
    setState(() {
      _lines.add(
        ChecklistTemplateDraftLine(
          title: '',
          isPhotoRequired: false,
          sortOrder: _lines.length,
        ),
      );
    });
  }

  void _removeAt(int index) {
    setState(() {
      if (index >= 0 && index < _lines.length) {
        _lines.removeAt(index);
      }
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final x = _lines.removeAt(oldIndex);
      _lines.insert(newIndex, x);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(taskChecklistItemsProvider(widget.taskId));

    return async.when(
      loading: () => ExpansionTile(
        title: Text('tasks.checklist_section'.tr()),
        children: const [
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      ),
      error: (err, stack) => const SizedBox.shrink(),
      data: (data) {
        if (!_draftReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _draftReady = true;
              _applySnapshot(data);
            });
          });
          return ExpansionTile(
            title: Text('tasks.checklist_section'.tr()),
            children: const [
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ],
          );
        }

        return ExpansionTile(
          initiallyExpanded: _lines.isNotEmpty,
          title: Text('tasks.checklist_section'.tr()),
          subtitle: Text(
            'tasks.checklist_section_subtitle'.tr(namedArgs: {'count': '${_lines.length}'}),
            style: context.textTheme.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'tasks.checklist_instance_manager_hint'.tr(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_lines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Text(
                        'tasks.checklist_instance_empty'.tr(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: _lines.length,
                      onReorder: (oldIndex, newIndex) {
                        if (widget.readOnly) {
                          return;
                        }
                        _reorder(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final line = _lines[index];
                        final sid = line.serverId?.trim();
                        final done = sid != null && sid.isNotEmpty ? (_itemCompleted[sid] == true) : false;
                        return _TaskInstanceDraftTile(
                          key: ValueKey(line.localKey),
                          index: index,
                          line: line,
                          readOnly: widget.readOnly,
                          workerCompleted: done,
                          onTitleChanged: widget.readOnly
                              ? (_) {}
                              : (v) => setState(() {
                                    _lines[index] = line.copyWith(title: v);
                                  }),
                          onPhotoRequiredChanged: widget.readOnly
                              ? (_) {}
                              : (v) => setState(() {
                                    _lines[index] = line.copyWith(isPhotoRequired: v);
                                  }),
                          onDelete: widget.readOnly ? () {} : () => _removeAt(index),
                        );
                      },
                    ),
                  if (!widget.readOnly) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add),
                      label: Text('checklists.add_item'.tr()),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Jedna položka instance – stejný UX jako editor šablony, navíc stav od workerů (read-only chip).
class _TaskInstanceDraftTile extends StatefulWidget {
  const _TaskInstanceDraftTile({
    super.key,
    required this.index,
    required this.line,
    required this.readOnly,
    required this.workerCompleted,
    required this.onTitleChanged,
    required this.onPhotoRequiredChanged,
    required this.onDelete,
  });

  final int index;
  final ChecklistTemplateDraftLine line;
  final bool readOnly;
  final bool workerCompleted;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<bool> onPhotoRequiredChanged;
  final VoidCallback onDelete;

  @override
  State<_TaskInstanceDraftTile> createState() => _TaskInstanceDraftTileState();
}

class _TaskInstanceDraftTileState extends State<_TaskInstanceDraftTile> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.line.title);
  }

  @override
  void didUpdateWidget(covariant _TaskInstanceDraftTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.localKey != widget.line.localKey ||
        (oldWidget.line.title != widget.line.title && _titleController.text != widget.line.title)) {
      _titleController.text = widget.line.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.readOnly)
              ReorderableDragStartListener(
                index: widget.index,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Icon(Icons.drag_handle, color: cs.outline),
                ),
              ),
            Expanded(
              child: TextField(
                controller: _titleController,
                readOnly: widget.readOnly,
                onChanged: widget.onTitleChanged,
                decoration: InputDecoration(
                  labelText: 'checklists.field_item_title'.tr(),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (widget.workerCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  label: Text('tasks.checklist_item_done_worker'.tr()),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            if (!widget.readOnly) ...[
              Tooltip(
                message: 'checklists.photo_required_tooltip'.tr(),
                child: IconButton(
                  icon: Icon(
                    widget.line.isPhotoRequired ? Icons.photo_camera : Icons.photo_camera_outlined,
                    color: widget.line.isPhotoRequired ? cs.primary : cs.outline,
                  ),
                  onPressed: () => widget.onPhotoRequiredChanged(!widget.line.isPhotoRequired),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: cs.error),
                tooltip: 'checklists.delete_item'.tr(),
                onPressed: widget.onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
