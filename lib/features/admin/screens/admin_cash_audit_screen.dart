import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/cash_audit_provider.dart';

/// Admin přehled „Hlídač hotovosti“ nad SQL view `vw_cash_collection_audit`.
///
/// PROČ: Finance tým potřebuje v jedné tabulce rychle vidět chybějící/duplicitní/nesouladné výběry
/// a hned otevřít detail úkolu pro opravu.
class AdminCashAuditScreen extends ConsumerWidget {
  const AdminCashAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(cashAuditAnomalyFilterProvider);
    final asyncRows = ref.watch(cashAuditRowsProvider(selectedFilter));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            'admin.finance.cash_audit_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CashAuditAnomalyFilter.values.map((filter) {
              final isSelected = filter == selectedFilter;
              return ChoiceChip(
                label: Text(_filterLabelKey(filter).tr()),
                selected: isSelected,
                onSelected: (_) {
                  ref.read(cashAuditAnomalyFilterProvider.notifier).state =
                      filter;
                },
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: asyncRows.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'admin.finance.cash_audit_load_error'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.error),
                ),
              ),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'admin.finance.cash_audit_empty'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return _CashAuditTile(row: row);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CashAuditTile extends ConsumerWidget {
  const _CashAuditTile({required this.row});

  final CashAuditRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateText = row.scheduledStart == null
        ? 'common.placeholder_dash'.tr()
        : DateFormat.yMMMd(
            context.locale.toString(),
          ).add_Hm().format(row.scheduledStart!.toLocal());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openTaskDetail(context, ref),
        child: Container(
          decoration: premiumCardDecoration(context),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.apartmentName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _AnomalyChip(type: row.anomalyType),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                row.taskTitle,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '${'admin.finance.cash_audit_date'.tr()}: $dateText',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AmountInfo(
                      label: 'admin.finance.cash_audit_expected'.tr(),
                      value: formatTaskAmount(context, ref, row.expectedCash),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AmountInfo(
                      label: 'admin.finance.cash_audit_collected'.tr(),
                      value: formatTaskAmount(context, ref, row.collectedCash),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _openTaskDetail(context, ref),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text('admin.finance.cash_audit_open_task'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTaskDetail(BuildContext context, WidgetRef ref) async {
    final task = await ref.read(taskByIdProvider(row.taskId).future);
    if (!context.mounted) return;
    if (task == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.finance.task_not_found'.tr())),
      );
      return;
    }
    AdminTasksScreen.showEditTaskDialog(context, ref, task);
  }
}

class _AmountInfo extends StatelessWidget {
  const _AmountInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: context.colors.outline),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AnomalyChip extends StatelessWidget {
  const _AnomalyChip({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _chipColors(context, type);
    return Chip(
      label: Text(_anomalyLabelKey(type).tr()),
      backgroundColor: bg,
      labelStyle: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  (Color, Color) _chipColors(BuildContext context, String value) {
    switch (value) {
      case 'missing_cash':
        return (context.colors.errorContainer, context.colors.onErrorContainer);
      case 'duplicate_cash':
        return (
          context.customColors.warning.withValues(alpha: 0.22),
          context.customColors.onWarning,
        );
      case 'amount_mismatch':
        return (context.colors.tertiaryContainer, context.colors.onTertiaryContainer);
      default:
        return (
          context.customColors.success.withValues(alpha: 0.18),
          context.customColors.onSuccess,
        );
    }
  }
}

String _filterLabelKey(CashAuditAnomalyFilter filter) {
  switch (filter) {
    case CashAuditAnomalyFilter.all:
      return 'admin.finance.cash_audit_filter_all';
    case CashAuditAnomalyFilter.missingCash:
      return 'admin.finance.cash_audit_filter_missing';
    case CashAuditAnomalyFilter.duplicateCash:
      return 'admin.finance.cash_audit_filter_duplicate';
    case CashAuditAnomalyFilter.amountMismatch:
      return 'admin.finance.cash_audit_filter_mismatch';
    case CashAuditAnomalyFilter.ok:
      return 'admin.finance.cash_audit_filter_ok';
  }
}

String _anomalyLabelKey(String anomalyType) {
  switch (anomalyType) {
    case 'missing_cash':
      return 'admin.finance.cash_audit_anomaly_missing';
    case 'duplicate_cash':
      return 'admin.finance.cash_audit_anomaly_duplicate';
    case 'amount_mismatch':
      return 'admin.finance.cash_audit_anomaly_mismatch';
    default:
      return 'admin.finance.cash_audit_anomaly_ok';
  }
}

