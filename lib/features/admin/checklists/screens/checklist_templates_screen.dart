import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/features/admin/checklists/screens/checklist_template_editor_screen.dart';
import 'package:falconest/features/admin/providers/checklist_templates_list_provider.dart';
import 'package:falconest/features/admin/repositories/checklist_template_repository.dart';
import 'package:falconest/features/tasks/models/checklists/checklist_template_model.dart';

/// Tělo seznamu šablon – bez Scaffold; vkládá se do [TabBarView] nebo do [Scaffold.body] samostatné routy.
///
/// [showHeaderAndAddButton]: v Nastavení zobrazíme řádek jako u Služeb/Oblastí (nadpis + modré tlačítko Přidat).
class ChecklistTemplatesTab extends ConsumerWidget {
  const ChecklistTemplatesTab({super.key, this.showHeaderAndAddButton = false});

  final bool showHeaderAndAddButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(checklistTemplatesListProvider);

    return async.when(
      data: (templates) {
        if (templates.isEmpty) {
          return _maybeWithHeader(
            context,
            ref,
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'checklists.templates_empty'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          );
        }
        return _maybeWithHeader(
          context,
          ref,
          ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final t = templates[index];
              return _ChecklistTemplateRow(
                template: t,
                onEdit: () => ChecklistTemplateEditorDialog.show(context, ref, templateId: t.id),
                onDelete: () => confirmDeleteChecklistTemplate(context, ref, t),
              );
            },
          ),
        );
      },
      loading: () => _maybeWithHeader(
        context,
        ref,
        const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => _maybeWithHeader(
        context,
        ref,
        Center(child: Text('checklists.templates_load_error'.tr())),
      ),
    );
  }

  /// Obalí obsah záložky hlavičkou (identickým vzorem jako [ZonesListTab] / katalog služeb v modalu).
  Widget _maybeWithHeader(BuildContext context, WidgetRef ref, Widget child) {
    if (!showHeaderAndAddButton) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'checklists.list_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[900],
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => ChecklistTemplateEditorDialog.show(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: Text('checklists.fab_new_template'.tr()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: child),
      ],
    );
  }
}

/// Samostatná trasa `/admin/checklist-templates` – pro bookmarky; stejný obsah jako záložka v Nastavení.
class ChecklistTemplatesScreen extends ConsumerWidget {
  const ChecklistTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('checklists.templates_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'common.back'.tr(),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: ChecklistTemplatesTab(showHeaderAndAddButton: true),
      ),
    );
  }
}

/// Potvrzení smazání šablony – sdílené z řádků seznamu.
Future<void> confirmDeleteChecklistTemplate(
  BuildContext context,
  WidgetRef ref,
  ChecklistTemplateModel t,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('checklists.delete_confirm_title'.tr()),
      content: Text('checklists.delete_confirm_body'.tr(namedArgs: {'name': t.name})),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('checklists.delete_confirm_action'.tr()),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  final tenantId = ref.read(authNotifierProvider).tenantIdForData;
  if (tenantId == null || tenantId.isEmpty) return;

  try {
    await ChecklistTemplateRepository.instance.deleteTemplate(tenantId, t.id);
    ref.invalidate(checklistTemplatesListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('checklists.delete_success'.tr())),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('checklists.delete_error'.tr())),
      );
    }
  }
}

/// Jeden řádek šablony – vizuálně zarovnaný s [_ZoneCardRow] / [_ServiceCardRow]: bílé pozadí, jemný stín, šedý leading.
///
/// PROČ: Checklisty jsou stejný typ master dat jako služby/oblasti; nesmí vizuálně vyčnívat [Card] s jiným stínem.
class _ChecklistTemplateRow extends StatelessWidget {
  const _ChecklistTemplateRow({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  final ChecklistTemplateModel template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final descRaw = template.description?.trim();
    final hasDesc = descRaw != null && descRaw.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.assignment_outlined, color: Colors.grey.shade700, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      template.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasDesc) ...[
                      const SizedBox(height: 4),
                      Text(
                        descRaw,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: template.isActive ? Colors.green.shade50 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    template.isActive ? 'checklists.status_active'.tr() : 'checklists.status_inactive'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: template.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey[700]),
                tooltip: 'checklists.action_edit'.tr(),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                tooltip: 'checklists.action_delete'.tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
