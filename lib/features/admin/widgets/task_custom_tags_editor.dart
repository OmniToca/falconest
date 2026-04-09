import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/models/task_custom_tag.dart';
import 'package:falconest/features/settings/widgets/app_color_picker_dialog.dart';

/// Editor vlastních štítků úkolu (text + barva) pro admin detail úkolu.
///
/// PROČ: Dispečink potřebuje rychlé označení (VIP, reklamace) bez změny DB schématu — data jdou do `metadata.custom_tags`.
class TaskCustomTagsEditor extends StatefulWidget {
  const TaskCustomTagsEditor({
    super.key,
    required this.initialTags,
    required this.onChanged,
    this.readOnly = false,
  });

  final List<TaskCustomTag> initialTags;
  final void Function(List<TaskCustomTag> tags) onChanged;
  final bool readOnly;

  @override
  State<TaskCustomTagsEditor> createState() => _TaskCustomTagsEditorState();
}

class _TaskCustomTagsEditorState extends State<TaskCustomTagsEditor> {
  late List<TaskCustomTag> _tags;
  final _newLabelController = TextEditingController();
  Color _newTagColor = const Color(0xFF5C6BC0);

  @override
  void initState() {
    super.initState();
    _tags = List<TaskCustomTag>.from(widget.initialTags);
  }

  @override
  void didUpdateWidget(covariant TaskCustomTagsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTags != widget.initialTags) {
      _tags = List<TaskCustomTag>.from(widget.initialTags);
    }
  }

  @override
  void dispose() {
    _newLabelController.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(List<TaskCustomTag>.from(_tags));
    setState(() {});
  }

  Future<void> _pickColorForNewTag() async {
    final c = await showAppColorPickerDialog(
      context: context,
      initialColor: _newTagColor,
    );
    if (c != null) setState(() => _newTagColor = c);
  }

  Future<void> _pickColorForIndex(int index) async {
    final c = await showAppColorPickerDialog(
      context: context,
      initialColor: _tags[index].color,
    );
    if (c != null) {
      _tags[index] = TaskCustomTag(label: _tags[index].label, color: c);
      _notify();
    }
  }

  void _addTag() {
    final label = _newLabelController.text.trim();
    if (label.isEmpty) return;
    _tags.add(TaskCustomTag(label: label, color: _newTagColor));
    _newLabelController.clear();
    _notify();
  }

  void _removeAt(int i) {
    _tags.removeAt(i);
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly && _tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.task_custom_tags_section'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'admin.task_custom_tags_hint'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
          ),
          SizedBox(height: AppSpacing.sm),
          if (_tags.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: List.generate(_tags.length, (i) {
                final t = _tags[i];
                return InputChip(
                  label: Text(
                    t.label,
                    style: TextStyle(
                      color: _contrastOn(t.color),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: t.color,
                  deleteIconColor: _contrastOn(t.color),
                  onDeleted: widget.readOnly ? null : () => _removeAt(i),
                  onPressed: widget.readOnly ? null : () => _pickColorForIndex(i),
                );
              }),
            ),
            SizedBox(height: AppSpacing.sm),
          ],
          if (!widget.readOnly) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: _newTagColor,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: _pickColorForNewTag,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.palette_outlined,
                        color: _contrastOn(_newTagColor),
                        size: 22,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _newLabelController,
                    decoration: InputDecoration(
                      labelText: 'admin.task_custom_tags_new_label'.tr(),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                FilledButton.tonal(
                  onPressed: _addTag,
                  child: Text('admin.task_custom_tags_add'.tr()),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// PROČ: Zajistí čitelnost textu na libovolném pastelovém pozadí štítku.
  Color _contrastOn(Color bg) {
    final r = (bg.r * 255.0).round();
    final g = (bg.g * 255.0).round();
    final b = (bg.b * 255.0).round();
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.55 ? Colors.black87 : Colors.white;
  }
}
