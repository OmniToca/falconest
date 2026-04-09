import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/models/task_category_model.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/features/communication/models/message_template_row.dart';
import 'package:falconest/features/communication/providers/message_templates_admin_provider.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/features/communication/utils/communication_error_helper.dart';
import 'package:falconest/features/communication/widgets/template_editor_dialog.dart';
import 'package:falconest/utils/task_visuals.dart';

/// Administrativní obrazovka správy šablon zpráv (Komunikace).
///
/// Agentury zde vytváří předpřipravené texty pro řidiče – rychlé WhatsApp zprávy
/// hostům s placeholdery ({guest_name}, {flight_number}…). Seznam seřazen podle
/// jazyka a trigger kontextu. Multi-tenant: data vázána na tenant_id.
class CommunicationTemplatesScreen extends ConsumerWidget {
  const CommunicationTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(messageTemplatesAdminProvider);

    return Scaffold(
      body: templatesAsync.when(
        data: (templates) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, ref),
              Expanded(
                child: templates.isEmpty
                    ? _buildEmptyState(context)
                    : _buildTemplatesList(context, ref, templates),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
              const SizedBox(height: 16),
              Text(
                'common.generic_error_user_friendly'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(messageTemplatesAdminProvider),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'communication.title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'communication.subtitle'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _showEditorDialog(context, ref),
            icon: const Icon(Icons.add, size: 20),
            label: Text('communication.add_template'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'communication.empty_list'.tr(),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesList(
    BuildContext context,
    WidgetRef ref,
    List<MessageTemplateRow> templates,
  ) {
    final categoriesByCode =
        ref.watch(taskCategoriesProvider).valueOrNull ??
        <String, TaskCategoryModel>{};
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final t = templates[index];
        // PROČ: Stejný prémiový obal jako Automatizace / nástěnka — žádné zastaralé Material Card.
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: premiumCardShell(
            context,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Icon(Icons.chat, color: Colors.green.shade800),
              ),
              title: Text(
                t.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _TriggerChip(
                        value: t.triggerContext,
                        categoriesByCode: categoriesByCode,
                      ),
                      const SizedBox(width: 8),
                      _ChannelChip(channel: t.channel),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.previewSnippet.isEmpty ? '–' : t.previewSnippet,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        _showEditorDialog(context, ref, template: t),
                    tooltip: 'communication.edit_template'.tr(),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade700,
                    ),
                    onPressed: () => _showDeleteConfirm(context, ref, t),
                    tooltip: 'admin.apartments_delete'.tr(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditorDialog(
    BuildContext context,
    WidgetRef ref, {
    MessageTemplateRow? template,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => TemplateEditorDialog(
        template: template,
        onSaved: () => ref.invalidate(messageTemplatesAdminProvider),
      ),
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    WidgetRef ref,
    MessageTemplateRow template,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('communication.template_delete_title'.tr()),
        content: Text('communication.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () async {
              try {
                await ref
                    .read(messageTemplatesAdminNotifierProvider.notifier)
                    .delete(template.id);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ref.invalidate(messageTemplatesAdminProvider);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('communication.deleted'.tr()),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'communication.delete_error'.tr(
                          namedArgs: {'error': userFacingCommunicationError(e)},
                        ),
                      ),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Text('communication.template_delete_button'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Malý chip pro zobrazení trigger kontextu (kategorie úkolu z task_categories).
/// Překlad přes admin.task_type_{code}, barva a ikona z TaskVisuals.
class _TriggerChip extends StatelessWidget {
  const _TriggerChip({this.value, this.categoriesByCode});

  final String? value;
  final Map<String, TaskCategoryModel>? categoriesByCode;

  @override
  Widget build(BuildContext context) {
    final isGeneral = value == null || value!.trim().isEmpty;
    final display = isGeneral
        ? 'communication.template_trigger_general'.tr()
        : 'admin.task_type_$value'.tr();
    final bgColor = isGeneral
        ? Colors.grey.shade100
        : TaskVisuals.getBackgroundColor(
            value,
            categoriesByCode: categoriesByCode,
          );
    final fgColor = isGeneral
        ? Colors.grey.shade700
        : TaskVisuals.getBorderColor(value, categoriesByCode: categoriesByCode);
    final icon = isGeneral
        ? Icons.chat_bubble_outline
        : TaskVisuals.getIcon(value, categoriesByCode: categoriesByCode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 4),
          Text(display, style: TextStyle(fontSize: 11, color: fgColor)),
        ],
      ),
    );
  }
}

/// Malý chip pro zobrazení komunikačního kanálu šablony.
class _ChannelChip extends StatelessWidget {
  const _ChannelChip({required this.channel});

  final String channel;

  @override
  Widget build(BuildContext context) {
    final c = channel.trim().toLowerCase();
    String labelKey;
    switch (c) {
      case 'sms':
        labelKey = 'communication.channel_sms';
        break;
      case 'email':
        labelKey = 'communication.channel_email';
        break;
      case 'whatsapp':
      default:
        labelKey = 'communication.channel_whatsapp';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        labelKey.tr(),
        style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
      ),
    );
  }
}
