import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/presentation/widgets/app_card.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/settlements_provider.dart';
import 'package:falconest/features/admin/widgets/payout_history_content.dart';
import 'package:falconest/features/admin/widgets/settlement_split_dialog.dart';

/// Obrazovka modulu Vyúčtování – fronta úkolů ke schválení, pohled "K výplatě" a Historie výplat.
///
/// Tři záložky: 1) Fronta úkolů – dokončené úkoly bez vyúčtování. 2) K výplatě – seskupené
/// pending výplaty/provize. 3) Historie výplat – uzamčené snapshoty z payout_snapshots (bez dialogu).
class AdminSettlementsScreen extends ConsumerWidget {
  const AdminSettlementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'admin.settlements.menu_title'.tr(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            TabBar(
              tabs: [
                Tab(text: context.tr('admin.settlements.tab_queue')),
                Tab(text: context.tr('admin.settlements.tab_payroll')),
                Tab(text: context.tr('admin.settlements.tab_history')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _QueueTabContent(),
                  _PayrollTabContent(),
                  const PayoutHistoryContent(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Záložka "Fronta úkolů" – dokončené úkoly ke schválení výplat a provizí.
class _QueueTabContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingSettlementsProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(
              'admin.settlements.pending_title'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
          ),
        ),
        pendingAsync.when(
          data: (tasks) {
            if (tasks.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'admin.settlements.empty_pending'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final task = tasks[index];
                  return _SettlementPendingTaskCard(
                    task: task,
                    onTap: () {
                      SettlementSplitDialog.show(
                        context,
                        ref: ref,
                        task: task,
                      );
                    },
                    formatAmount: (v) => formatWalletAmount(context, ref, v),
                  );
                },
                childCount: tasks.length,
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                  const SizedBox(height: 16),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// Záložka "K výplatě" – seskupené pending výplaty, rozbalovací detail po úkolech a karta celkového zisku agentury.
class _PayrollTabContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(groupedPendingPayoutsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: dataAsync.when(
            data: (data) {
              final groups = data.groups;
              if (groups.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'admin.settlements.empty_payroll'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  // Karta celkového zisku agentury (marže) – souhrn po schválení výplat
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'admin.settlements.agency_margin_total_title'.tr(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if ('admin.settlements.agency_margin_total_subtitle'.tr().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'admin.settlements.agency_margin_total_subtitle'.tr(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            formatWalletAmount(context, ref, data.agencyMarginTotal),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'admin.settlements.margin_breakdown_invoiced'.tr(),
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              Text(
                                formatWalletAmount(context, ref, data.totalTaskValue),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'admin.settlements.margin_breakdown_costs'.tr(),
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              Text(
                                '- ${formatWalletAmount(context, ref, data.totalPayouts)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          if (data.taskMargins.isNotEmpty) ...[
                            const Divider(height: 24),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(top: 8, bottom: 4),
                              title: Text(
                                'admin.settlements.margin_show_details'.tr(),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                              children: [
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: data.taskMargins.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final t = data.taskMargins[index];
                                    final marginColor = t.margin >= 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  t.taskTitle,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                formatWalletAmount(context, ref, t.margin),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: marginColor,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${'admin.settlements.margin_breakdown_invoiced'.tr()}: ${formatWalletAmount(context, ref, t.invoiced)} | ${'admin.settlements.margin_breakdown_costs'.tr()}: ${formatWalletAmount(context, ref, t.costs)}',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: Colors.grey.shade600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  ...groups.map(
                    (group) => _PayrollGroupCard(
                      group: group,
                      formatAmount: (v) => formatWalletAmount(context, ref, v),
                      onMarkAsPaid: () => _handleMarkAsPaid(context, ref, group),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                  const SizedBox(height: 16),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleMarkAsPaid(BuildContext context, WidgetRef ref, PayoutGroup group) async {
    try {
      await markPayoutGroupAsPaid(ref: ref, group: group);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.settlements.paid_success'.tr())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}

/// Karta jedné skupiny k výplatě – rozbalovací seznam úkolů (název, datum, částka) a tlačítko Označit jako vyplaceno.
class _PayrollGroupCard extends StatelessWidget {
  const _PayrollGroupCard({
    required this.group,
    required this.formatAmount,
    required this.onMarkAsPaid,
  });

  final PayoutGroup group;
  final String Function(double) formatAmount;
  final VoidCallback onMarkAsPaid;

  @override
  Widget build(BuildContext context) {
    final hasItems = group.items.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                leading: Icon(
                  group.isEmployee ? Icons.person : Icons.business,
                  size: 20,
                  color: group.isEmployee ? Colors.blue.shade700 : Colors.purple.shade700,
                ),
                title: Text(
                  group.recipientName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat.yMMMM(context.locale.toString()).format(group.taskMonth),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      Text(
                        formatAmount(group.totalAmount),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
                children: hasItems
                    ? [
                        // Rozbalovací seznam – detailní přehled výplat po úkolech
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'admin.settlements.payroll_item_task'.tr(),
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(
                                'admin.settlements.payroll_item_date'.tr(),
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                'admin.settlements.payroll_item_amount'.tr(),
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...group.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.taskTitle.isEmpty ? '—' : item.taskTitle,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    item.date != null
                                        ? DateFormat('dd.MM.yyyy', context.locale.toString()).format(item.date!)
                                        : '—',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey.shade700,
                                        ),
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    formatAmount(item.amount),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]
                    : [],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onMarkAsPaid,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: Text('admin.settlements.mark_as_paid'.tr()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zjednodušená karta úkolu čekajícího na vyúčtování.
///
/// PROČ: Přehledný náhled – název úkolu, typ, datum, přiřazení. Kliknutím otevře dialog.
class _SettlementPendingTaskCard extends StatelessWidget {
  const _SettlementPendingTaskCard({
    required this.task,
    required this.onTap,
    required this.formatAmount,
  });

  final TaskRow task;
  final VoidCallback onTap;
  final String Function(double) formatAmount;

  /// Extrahuje celkovou hodnotu úkolu z metadata (amount_to_collect nebo service_price).
  double get _totalTaskPrice {
    final meta = task.metadata;
    if (meta == null || meta.isEmpty) return 0;
    final amt = meta['amount_to_collect'];
    if (amt != null) {
      final v = amt is num ? amt.toDouble() : double.tryParse(amt.toString());
      return v ?? 0;
    }
    final svc = meta['service_price'];
    if (svc != null) {
      final v = svc is num ? svc.toDouble() : double.tryParse(svc.toString());
      return v ?? 0;
    }
    return 0;
  }

  /// Úkol je pro externího klienta/agenturu – zobrazíme badge pro rychlý kontext.
  bool get _isExternalTask =>
      task.clientId != null && task.clientId!.isNotEmpty;

  /// Datum k zobrazení: preferujeme scheduledStart, jinak dueDate (pro kontext ve frontě).
  DateTime? get _displayDate => task.scheduledStart ?? task.dueDate;

  @override
  Widget build(BuildContext context) {
    final totalStr = _totalTaskPrice > 0
        ? formatAmount(_totalTaskPrice)
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
            child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Řádek s názvem a volitelným odznakem „Externí“ – kontext pro finanční rozhodování
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (_isExternalTask) ...[
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(
                              'admin.settlements.external_client_badge'.tr(),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.orange.shade800,
                                  ),
                            ),
                            backgroundColor: Colors.orange.shade50,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                    // Datum úkolu (scheduledStart nebo dueDate) – formát dd.MM.yyyy HH:mm pro kontext při schvalování
                    if (_displayDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${'admin.settlements.task_date_label'.tr()}: ${DateFormat('dd.MM.yyyy HH:mm', context.locale.toString()).format(_displayDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (task.apartmentName != null &&
                            task.apartmentName!.isNotEmpty)
                          Text(
                            task.apartmentName!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        if (task.assignedToName != null &&
                            task.assignedToName!.isNotEmpty) ...[
                          if (task.apartmentName != null &&
                              task.apartmentName!.isNotEmpty)
                            Text(
                              ' • ',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          Text(
                            task.assignedToName!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalStr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}
