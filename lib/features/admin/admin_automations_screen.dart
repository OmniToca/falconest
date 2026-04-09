import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/admin_automation_rule_form.dart';
import 'package:falconest/core/models/automation/automation_enums.dart';
import 'package:falconest/core/models/automation/automation_rule_row.dart';
import 'package:falconest/features/admin/providers/automation_rules_provider.dart';
import 'package:falconest/core/models/automation/automation_queue_row.dart';
import 'package:falconest/features/admin/providers/automation_queue_provider.dart';
import 'package:falconest/core/models/automation/tenant_message_log_row.dart';
import 'package:falconest/features/admin/providers/automation_log_provider.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/services/automations_seeder_service.dart';
import 'package:falconest/features/admin/widgets/ad_hoc_message_dialog.dart';
import 'package:falconest/features/admin/providers/admin_automation_tab_index_provider.dart';
import 'package:falconest/features/admin/providers/admin_automation_filter_provider.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';

/// Hlavní obrazovka modulu **Automatizace** v administraci agentury (Fáze 3 – provozní UI).
///
/// PROČ: Centrální místo pro plánované a ad-hoc zprávy napojené na automatizace: **Pravidla**
/// (`automation_rules` přes [automationRulesProvider]), **Čekárna** (`automation_message_queue`
/// přes [automationQueueProvider]), **Historie** odeslaných zpráv (`tenant_message_log` přes
/// [automationLogProvider]). Odeslání řeší Edge `automation-dispatch` (cron / „Odeslat okamžitě“
/// z fronty). **Šablony zpráv** (`message_templates`) se spravují v samostatné obrazovce modulu
/// Komunikace; pravidla na ně odkazují přes `template_id`. Obrazovka má **3 záložky** (Pravidla,
/// Čekárna, Historie) – šablony jsou čtvrtý pilíř produktu, ale vlastní route mimo tento widget.
class AdminAutomationsScreen extends ConsumerWidget {
  const AdminAutomationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(adminAutomationFilterProvider);
    final watchedTabIndex = ref.watch(adminAutomationTabIndexProvider);
    final initialIndexRaw = filterState?.preferredTabIndex ?? watchedTabIndex;
    final initialIndex = initialIndexRaw < 0
        ? 0
        : initialIndexRaw > 2
        ? 2
        : initialIndexRaw;
    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: TabBarView(
                children: [
                  _buildRulesTab(context, ref),
                  _buildQueueTab(context, ref, filterState),
                  _buildLogTab(context, ref, filterState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin.automations_title'.tr(),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TabBar(
            tabs: [
              Tab(text: 'admin.automations_tab_rules'.tr()),
              Tab(text: 'admin.automations_tab_queue'.tr()),
              Tab(text: 'admin.automations_tab_log'.tr()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesTab(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(automationRulesProvider);

    return rulesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          Center(child: Text('common.generic_error_user_friendly'.tr())),
      data: (rules) {
        if (rules.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.smart_toy_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'admin.automations_empty_rules'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      final tenantId = ref
                          .read(authNotifierProvider)
                          .tenantIdForData;
                      if (tenantId == null || tenantId.isEmpty) return;
                      try {
                        await AutomationsSeederService.seedDefaultAutomations(
                          tenantId,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'admin.automations_seed_success'.tr(),
                            ),
                          ),
                        );
                        ref.invalidate(automationRulesProvider);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'common.generic_error_user_friendly'.tr(),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: Text('admin.automations_seed_defaults'.tr()),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        AdminAutomationRuleFormDialog.show(context),
                    icon: const Icon(Icons.add, size: 20),
                    label: Text('admin.automations_add_rule'.tr()),
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => AdminAutomationRuleFormDialog.show(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: Text('admin.automations_add_rule'.tr()),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () async {
                    final tenantId = ref
                        .read(authNotifierProvider)
                        .tenantIdForData;
                    if (tenantId == null || tenantId.isEmpty) return;
                    try {
                      await AutomationsSeederService.seedDefaultAutomations(
                        tenantId,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('admin.automations_seed_success'.tr()),
                        ),
                      );
                      ref.invalidate(automationRulesProvider);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'common.generic_error_user_friendly'.tr(),
                          ),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: Text('admin.automations_seed_defaults'.tr()),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: rules.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final rule = rules[i];
                    return _RuleCard(
                      rule: rule,
                      onToggleActive: (v) {
                        ref
                            .read(automationRulesProvider.notifier)
                            .toggleRuleActive(rule.id, v);
                      },
                      onEdit: () {
                        AdminAutomationRuleFormDialog.show(
                          ctx,
                          ruleToEdit: rule,
                        );
                      },
                      onDelete: () {
                        _confirmDeleteRule(ctx, ref, rule);
                      },
                      triggerLabel: _triggerLabel(rule.triggerEvent),
                      channelLabel: _channelLabel(rule.channel),
                      channelIcon: _channelIcon(rule.channel),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQueueTab(
    BuildContext context,
    WidgetRef ref,
    AdminAutomationFilterState? filterState,
  ) {
    final queueAsync = ref.watch(automationQueueProvider);
    final showQueueFocus = filterState?.showFailedQueue == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showQueueFocus)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Material(
              color: Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  'admin.automations_filter_failed_queue_hint'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.add_comment_outlined, size: 20),
              label: Text('admin.queue_new_adhoc'.tr()),
              onPressed: () => AdHocMessageDialog.show(context),
            ),
          ),
        ),
        Expanded(
          child: queueAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) =>
                Center(child: Text('common.generic_error_user_friendly'.tr())),
            data: (queue) {
              if (queue.isEmpty) {
                return Center(
                  child: _EmptyState(
                    icon: Icons.hourglass_empty_rounded,
                    text: 'admin.queue_empty'.tr(),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: ListView.separated(
                  itemCount: queue.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final item = queue[i];
                    return _QueueCard(
                      item: item,
                      onCancel: () => _confirmCancelQueueItem(ctx, ref, item),
                      onSendNow: () => _confirmSendNowQueueItem(ctx, ref, item),
                      onEdit: () => _showEditQueuePayloadDialog(ctx, ref, item),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogTab(
    BuildContext context,
    WidgetRef ref,
    AdminAutomationFilterState? filterState,
  ) {
    final logAsync = ref.watch(automationLogProvider);
    final showFailedLogOnly = filterState?.showFailedLog == true;

    return logAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          Center(child: Text('common.generic_error_user_friendly'.tr())),
      data: (logs) {
        final effectiveLogs = showFailedLogOnly
            ? logs.where((l) {
                final s = l.status.trim().toLowerCase();
                return s == 'failed_at_provider' ||
                    s == 'failed' ||
                    s == 'cancelled';
              }).toList()
            : logs;

        if (effectiveLogs.isEmpty) {
          return Center(
            child: _EmptyState(
              icon: Icons.history_rounded,
              text: showFailedLogOnly
                  ? 'admin.automations_filter_failed_log_empty'.tr()
                  : 'admin.log_empty'.tr(),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: ListView.separated(
            itemCount: effectiveLogs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final log = effectiveLogs[i];
              return _LogCard(log: log, highlightFailed: showFailedLogOnly);
            },
          ),
        );
      },
    );
  }
}

String _triggerLabel(String triggerEvent) {
  // PROČ: UI zobrazuje “lidský” popis místo raw DB stringů.
  switch (triggerEvent.trim()) {
    case 'reservation_check_in':
      return 'admin.rule_trigger_reservation_check_in'.tr();
    case 'reservation_check_out':
      return 'admin.rule_trigger_reservation_check_out'.tr();
    case 'task_start':
      return 'admin.rule_trigger_task_start'.tr();
    default:
      return triggerEvent;
  }
}

String _channelLabel(AutomationChannel channel) {
  switch (channel) {
    case AutomationChannel.email:
      return 'admin.rule_channel_email'.tr();
    case AutomationChannel.sms:
      return 'admin.rule_channel_sms'.tr();
    case AutomationChannel.whatsapp:
      return 'admin.rule_channel_whatsapp'.tr();
    case AutomationChannel.internalPush:
      return 'admin.rule_channel_internal_push'.tr();
  }
}

IconData _channelIcon(AutomationChannel channel) {
  switch (channel) {
    case AutomationChannel.email:
      return Icons.email_outlined;
    case AutomationChannel.sms:
      return Icons.sms_outlined;
    case AutomationChannel.whatsapp:
      return Icons.phone_in_talk;
    case AutomationChannel.internalPush:
      return Icons.notifications_active_outlined;
  }
}

Future<void> _confirmDeleteRule(
  BuildContext context,
  WidgetRef ref,
  AutomationRuleRow rule,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: Text('admin.rule_delete_confirm_title'.tr()),
        content: Text(
          'admin.rule_delete_confirm_body'.tr(namedArgs: {'name': rule.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.ok'.tr()),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return;

  try {
    await ref.read(automationRulesProvider.notifier).deleteRule(rule.id);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('common.generic_error_user_friendly'.tr()),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
    required this.triggerLabel,
    required this.channelLabel,
    required this.channelIcon,
  });

  final AutomationRuleRow rule;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String triggerLabel;
  final String channelLabel;
  final IconData channelIcon;

  @override
  Widget build(BuildContext context) {
    // PROČ: Sjednocený prémiový shell místo Card — stejný vizuál jako Komunikace / Finance.
    return premiumCardShell(
      context,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(rule.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Icon(
              channelIcon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$triggerLabel • $channelLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: rule.isActive, onChanged: onToggleActive),
            IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

String _extractEditableText(Map<String, dynamic> payload) {
  // PROČ: `editable_payload` je JSONB a prozatím neznáme přesnou strukturu
  // napříč tenanty. Proto podporujeme několik common aliasů.
  final vText = payload['text'];
  if (vText is String) return vText;

  final vBody = payload['body'];
  if (vBody is String) return vBody;

  final vMessage = payload['message'];
  if (vMessage is String) return vMessage;

  return '';
}

String _formatQueueScheduledFor(BuildContext context, DateTime dtUtc) {
  final local = dtUtc.toLocal();
  return DateFormat('d.M. HH:mm', context.locale.languageCode).format(local);
}

/// PROČ: Ad-hoc řádky zobrazují příjemce; ostatní typy entit ponecháme technický náhled.
String _queueRecipientLabel(AutomationQueueRow item) {
  final t = item.entityType.trim().toLowerCase();
  if (t == 'adhoc') {
    final r = item.recipientContact?.trim();
    if (r != null && r.isNotEmpty) return r;
    return 'admin.queue_adhoc_badge'.tr();
  }
  if (item.recipientContact?.trim().isNotEmpty == true) {
    return item.recipientContact!.trim();
  }
  return '${item.entityType}:${item.entityId}';
}

Future<void> _confirmSendNowQueueItem(
  BuildContext context,
  WidgetRef ref,
  AutomationQueueRow item,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: Text('admin.queue_send_now_confirm_title'.tr()),
        content: Text('admin.queue_send_now_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('admin.queue_send_now_confirm_action'.tr()),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return;

  try {
    await ref.read(automationQueueProvider.notifier).sendNow(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('admin.queue_send_now_success'.tr()),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    final message =
        e is StateError && e.message == 'automation_queue.error_no_session'
        ? 'admin.queue_error_no_session'.tr()
        : 'common.generic_error_user_friendly'.tr();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

Future<void> _confirmCancelQueueItem(
  BuildContext context,
  WidgetRef ref,
  AutomationQueueRow item,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: Text('admin.queue_cancel_confirm_title'.tr()),
        content: Text(
          'admin.queue_cancel_confirm_body'.tr(
            namedArgs: {
              'when': _formatQueueScheduledFor(context, item.scheduledFor),
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.ok'.tr()),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return;

  try {
    await ref.read(automationQueueProvider.notifier).cancelMessage(item.id);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('common.generic_error_user_friendly'.tr()),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

Future<void> _showEditQueuePayloadDialog(
  BuildContext context,
  WidgetRef ref,
  AutomationQueueRow item,
) async {
  final initialText = _extractEditableText(item.editablePayload);
  final controller = TextEditingController(text: initialText);
  // PROČ: U dlouhých zpráv musí být vidět větší výřez a jasný scroll; TextField
  // sdílí ScrollController se Scrollbarem, aby uživatel poznal, že text pokračuje níže.
  final scrollController = ScrollController();

  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.55;
      return AlertDialog(
        title: Text('admin.queue_edit_payload_title'.tr()),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: maxH),
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            child: TextField(
              controller: controller,
              scrollController: scrollController,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 4,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: 'admin.queue_edit_payload_text_label'.tr(),
                hintText: 'admin.queue_edit_payload_text_hint'.tr(),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.save'.tr()),
          ),
        ],
      );
    },
  );

  controller.dispose();
  scrollController.dispose();

  if (saved != true) return;

  try {
    await ref
        .read(automationQueueProvider.notifier)
        .updateMessagePayload(item.id, controller.text);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('common.generic_error_user_friendly'.tr()),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.item,
    required this.onCancel,
    required this.onSendNow,
    required this.onEdit,
  });

  final AutomationQueueRow item;
  final VoidCallback onCancel;
  final VoidCallback onSendNow;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final channelIcon = _channelIcon(item.channel);
    final recipient = _queueRecipientLabel(item);

    // PROČ: Prémiový obal shodný se šablonami a pravidly — bez plochého Card.
    return premiumCardShell(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  channelIcon,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _formatQueueScheduledFor(context, item.scheduledFor),
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              recipient,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            // PROČ: OverflowBar zalomí tlačítka na úzkých displejích; pořadí dle zadání.
            OverflowBar(
              spacing: 8,
              overflowSpacing: 8,
              alignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text('admin.queue_cancel_button'.tr()),
                ),
                FilledButton.tonalIcon(
                  onPressed: onSendNow,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: Text('admin.queue_send_now'.tr()),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text('admin.queue_edit_button'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Karta jednoho záznamu v historii zpráv (odeslaných i příchozích).
///
/// PROČ: Stavy `sent` vs `delivered` rozlišujeme vizuálně – u Twilio/SMS/WhatsApp
/// se finální `delivered` často doplní **asynchronně** přes Twilio Status Callback
/// (edge funkce `twilio-webhook`), takže uživatel může chvíli vidět „čeká na doručení“.
///
/// Příchozí odpovědi hosta (`direction == inbound`) přicházejí z Twilio inbound webhooku
/// (`twilio-inbound`) a zobrazujeme je jinou bublinou + text z `inbound_text`.
class _LogCard extends StatelessWidget {
  const _LogCard({required this.log, this.highlightFailed = false});

  final TenantMessageLogRow log;
  final bool highlightFailed;

  /// PROČ: Dispatch ukládá do `metadata.num_segments` počet Twilio segmentů – zobrazíme
  /// jen u odchozích SMS, aby byl vidět rozdíl účtování oproti jedné „zprávě“ v UI.
  int? _smsSegmentCount() {
    if (log.channel != AutomationChannel.sms) return null;
    final m = log.metadata;
    if (m == null) return null;
    final raw = m['num_segments'];
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isInbound = log.direction.trim().toLowerCase() == 'inbound';

    final s = log.status.trim().toLowerCase();
    final isSent = s == 'sent';
    final isDelivered = s == 'delivered';
    // PROČ: V DB používáme `failed_at_provider`; `failed` necháváme pro případné aliasy.
    final isFailed = s == 'failed_at_provider' || s == 'failed';
    // PROČ: Resend webhook (`resend-webhook`) – stížnost na spam / dočasné zpoždění doručení.
    final isComplained = s == 'complained';
    final isDeliveryDelayed = s == 'delivery_delayed';

    final statusIcon = isDelivered
        ? Icons.check_circle_outline
        : isFailed
        ? Icons.cancel_outlined
        : isComplained
        ? Icons.report_gmailerrorred_outlined
        : isDeliveryDelayed
        ? Icons.hourglass_top_outlined
        : isSent
        ? Icons.schedule
        : Icons.help_outline;
    final scheme = Theme.of(context).colorScheme;
    final statusColor = isDelivered
        ? scheme.primary
        : isFailed
        ? scheme.error
        : isComplained
        ? scheme.tertiary
        : isDeliveryDelayed
        ? scheme.secondary
        : isSent
        ? scheme.primary
        : scheme.onSurfaceVariant;

    final statusLabel = isInbound
        ? 'admin.log_direction_inbound'.tr()
        : isDelivered
        ? 'admin.log_status_delivered'.tr()
        : isFailed
        ? 'admin.log_status_failed'.tr()
        : isComplained
        ? 'admin.log_status_complained'.tr()
        : isDeliveryDelayed
        ? 'admin.log_status_delivery_delayed'.tr()
        : isSent
        ? 'admin.log_status_sent'.tr()
        : log.status;

    final bodyText = isInbound
        ? (log.inboundText ?? log.contentSnapshot)
        : log.contentSnapshot;

    final priceText = (log.unitPrice != null && log.unitPrice! > 0)
        ? log.unitPrice!.toStringAsFixed(2)
        : null;

    final sentAtLocalStr = DateFormat(
      'd.M. HH:mm',
      context.locale.languageCode,
    ).format(log.sentAt.toLocal());

    final channelIcon = _channelIcon(log.channel);
    final channelLabel = _channelLabel(log.channel);

    final smsSegments = !isInbound ? _smsSegmentCount() : null;

    // PROČ: Příchozí zpráva = jiná ikona než stav doručení outbound zprávy.
    final leadingIcon = isInbound ? Icons.call_received : statusIcon;
    final leadingColor = isInbound
        ? Theme.of(context).colorScheme.primary
        : statusColor;

    final sForBg = log.status.trim().toLowerCase();
    final isFailedForBg =
        sForBg == 'failed_at_provider' ||
        sForBg == 'failed' ||
        sForBg == 'cancelled';

    // PROČ: Prémiový shell + volitelný nádech errorContainer při filtru „jen neúspěšné“.
    return premiumCardShell(
      context,
      child: Container(
        color: highlightFailed && isFailedForBg
            ? Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.30)
            : null,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(leadingIcon, size: 20, color: leadingColor),
          title: Row(
            children: [
              Text(
                sentAtLocalStr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 12),
              Icon(
                channelIcon,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  channelLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  log.recipientMasked ?? 'common.placeholder_dash'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isInbound
                        ? Theme.of(context).colorScheme.primary
                        : statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          trailing: priceText == null
              ? null
              : Text(
                  'admin.log_price'.tr(namedArgs: {'price': priceText}),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            if (smsSegments != null && smsSegments > 0) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'admin.log_sms_segments'.tr(
                    namedArgs: {'count': '$smsSegments'},
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: isInbound
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isInbound
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.45)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: isInbound
                      ? Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.35),
                        )
                      : null,
                ),
                child: Text(
                  bodyText,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: isInbound ? TextAlign.left : TextAlign.right,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
