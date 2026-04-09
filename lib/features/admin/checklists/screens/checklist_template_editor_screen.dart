import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/presentation/widgets/modern_admin_panel.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/features/admin/providers/checklist_template_editor_provider.dart';
import 'package:falconest/features/admin/providers/checklist_templates_list_provider.dart';
import 'package:falconest/features/admin/repositories/checklist_template_repository.dart';

/// Editor jedné šablony v admin design systému – [ModernAdminPanel] (dialog), ne full-screen route.
///
/// PROČ: CEO / UX – stejný vzor jako „Nový úkol“ nebo [ClientFormDialog]: titulek, křížek, scrollovatelný obsah,
/// patička se Zrušit / Uložit. [templateId] == null znamená novou šablonu.
class ChecklistTemplateEditorDialog extends ConsumerStatefulWidget {
  const ChecklistTemplateEditorDialog({super.key, this.templateId});

  /// UUID existující šablony, nebo null pro novou.
  final String? templateId;

  /// Otevře standardizovaný dialog; před zobrazením invaliduje family provider, aby byl draft vždy čistý
  /// při opakovaném otevření (např. dvakrát „Nová šablona“ za sebou).
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    String? templateId,
  }) {
    ref.invalidate(checklistTemplateEditorProvider(templateId));
    return showDialog<void>(
      context: context,
      builder: (ctx) => ChecklistTemplateEditorDialog(templateId: templateId),
    );
  }

  @override
  ConsumerState<ChecklistTemplateEditorDialog> createState() =>
      _ChecklistTemplateEditorDialogState();
}

class _ChecklistTemplateEditorDialogState extends ConsumerState<ChecklistTemplateEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _syncedHeaderFromState = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChecklistTemplateEditorDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.templateId != widget.templateId) {
      _syncedHeaderFromState = false;
    }
  }

  /// Propíše názvy z [ChecklistTemplateEditorState] do textových polí jen jednou po načtení – ne při každém keystroke.
  void _syncHeaderIfNeeded(ChecklistTemplateEditorState state) {
    if (state.isLoading || _syncedHeaderFromState) return;
    _nameController.text = state.name;
    _descriptionController.text = state.description;
    _syncedHeaderFromState = true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checklistTemplateEditorProvider(widget.templateId));
    final notifier = ref.read(checklistTemplateEditorProvider(widget.templateId).notifier);
    _syncHeaderIfNeeded(state);

    final title = state.templateId == null
        ? 'checklists.editor_title_new'.tr()
        : 'checklists.editor_title_edit'.tr();

    return ModernAdminPanel(
      title: title,
      maxWidth: 800,
      content: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.errorMessageKey != null && !state.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        state.errorMessageKey!.tr(),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  TextField(
                    controller: _nameController,
                    onChanged: notifier.setName,
                    decoration: InputDecoration(
                      labelText: 'checklists.field_template_name'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _descriptionController,
                    onChanged: notifier.setDescription,
                    decoration: InputDecoration(
                      labelText: 'checklists.field_template_description'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    title: Text('checklists.field_template_active'.tr()),
                    value: state.isActive,
                    onChanged: notifier.setIsActive,
                  ),
                  const Divider(height: AppSpacing.lg),
                  Text(
                    'checklists.section_items'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  if (state.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Text(
                        'checklists.items_empty_hint'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: state.items.length,
                      onReorder: notifier.reorderItems,
                      itemBuilder: (context, index) {
                        final line = state.items[index];
                        return _DraftItemTile(
                          key: ValueKey(line.localKey),
                          index: index,
                          line: line,
                          onTitleChanged: (v) => notifier.updateItemTitle(index, v),
                          onPhotoRequiredChanged: (v) => notifier.updateItemPhotoRequired(index, v),
                          onDelete: () => notifier.removeItemAt(index),
                        );
                      },
                    ),
                  SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: notifier.addItem,
                    icon: const Icon(Icons.add),
                    label: Text('checklists.add_item'.tr()),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: state.isSaving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: state.isSaving ? null : () => _save(context, notifier),
          child: state.isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, ChecklistTemplateEditorNotifier notifier) async {
    final ok = await notifier.save();
    if (!context.mounted) return;
    final err = ref.read(checklistTemplateEditorProvider(widget.templateId)).errorMessageKey;
    if (ok) {
      ref.invalidate(checklistTemplatesListProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('checklists.save_success'.tr())),
      );
    } else if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.tr())),
      );
    }
  }
}

class _DraftItemTile extends StatefulWidget {
  const _DraftItemTile({
    super.key,
    required this.index,
    required this.line,
    required this.onTitleChanged,
    required this.onPhotoRequiredChanged,
    required this.onDelete,
  });

  final int index;
  final ChecklistTemplateDraftLine line;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<bool> onPhotoRequiredChanged;
  final VoidCallback onDelete;

  @override
  State<_DraftItemTile> createState() => _DraftItemTileState();
}

class _DraftItemTileState extends State<_DraftItemTile> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.line.title);
  }

  @override
  void didUpdateWidget(covariant _DraftItemTile oldWidget) {
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
                onChanged: widget.onTitleChanged,
                decoration: InputDecoration(
                  labelText: 'checklists.field_item_title'.tr(),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
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
        ),
      ),
    );
  }
}
