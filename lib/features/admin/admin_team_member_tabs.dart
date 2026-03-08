// Kontextové záložky Úkoly a Finance pro detail člena týmu (_EditMemberDialog).
// Design konzistentní s ClientDetailDialog a _EditApartmentDialog.

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/core/presentation/widgets/app_card.dart';

/// True, pokud je úkol dokončený nebo zrušený (řadí se na konec).
bool isMemberTaskCompletedOrCancelled(TaskRow t) {
  final s = t.status.trim().toLowerCase();
  return s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno' || s == 'cancelled';
}

/// Datum pro řazení úkolu (scheduled_start nebo due_date).
DateTime memberTaskSortDate(TaskRow t) {
  final start = t.scheduledStart;
  if (start != null) return start;
  return t.dueDate;
}

/// Seřadí úkoly: aktivní/blížící se nahoře (ASC), dokončené dole.
List<TaskRow> sortMemberTasks(List<TaskRow> list) {
  final sorted = List<TaskRow>.from(list);
  sorted.sort((a, b) {
    final aEnd = isMemberTaskCompletedOrCancelled(a) ? 1 : 0;
    final bEnd = isMemberTaskCompletedOrCancelled(b) ? 1 : 0;
    if (aEnd != bEnd) return aEnd.compareTo(bEnd);
    return memberTaskSortDate(a).compareTo(memberTaskSortDate(b));
  });
  return sorted;
}

/// Záložka Úkoly v detailu člena – aktivní nahoře, dokončené pod tlačítkem „Zobrazit historii dokončených (N)“.
class MemberTasksTab extends ConsumerStatefulWidget {
  const MemberTasksTab({
    super.key,
    required this.member,
    required this.onTaskSaved,
  });

  final TeamMember member;
  final VoidCallback onTaskSaved;

  @override
  ConsumerState<MemberTasksTab> createState() => _MemberTasksTabState();
}

class _MemberTasksTabState extends ConsumerState<MemberTasksTab> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final profileId = widget.member.profileId ?? widget.member.id;
    final tasksAsync = ref.watch(tasksForMemberProvider(profileId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.tab_tasks'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                if (tasks.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'clients.client_no_tasks'.tr(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final sorted = sortMemberTasks(tasks);
                final completed = sorted.where(isMemberTaskCompletedOrCancelled).toList();
                final active = sorted.where((t) => !isMemberTaskCompletedOrCancelled(t)).toList();
                final visible = _showHistory ? sorted : active;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'clients.client_no_tasks'.tr(),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final t = visible[index];
                        final displayTitle = (t.customTitle ?? t.title).trim().isNotEmpty
                            ? (t.customTitle ?? t.title)
                            : (t.apartmentName ?? t.apartmentId);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(Icons.task_alt, color: Colors.teal.shade700),
                            title: Text(displayTitle, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              _taskStatusLabel(t.status),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              AdminTasksScreen.showEditTaskDialog(
                                context,
                                ref,
                                t,
                                onSaved: widget.onTaskSaved,
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            if (completed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextButton.icon(
                  icon: Icon(
                    _showHistory ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  label: Text(
                    _showHistory
                        ? 'common.hide_history'.tr()
                        : 'common.show_history_count'.tr(namedArgs: {'count': '${completed.length}'}),
                  ),
                  onPressed: () => setState(() => _showHistory = !_showHistory),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
              const SizedBox(height: 16),
              Text(
                'common.error_with_message'.tr(namedArgs: {'message': err.toString()}),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
            ),
          ),
        ],
      ),
    );
  }

  String _taskStatusLabel(String? status) {
    if (status == null || status.trim().isEmpty) return 'task_status.pending'.tr();
    final s = status.trim().toLowerCase();
    if (s == 'completed' || s == 'done' || s == 'hotovo' || s == 'dokončeno') return 'task_status.completed'.tr();
    if (s == 'cancelled') return 'task_status.cancelled'.tr();
    if (s == 'in_progress' || s == 'probíhá') return 'task_status.in_progress'.tr();
    if (s == 'assigned' || s == 'new' || s == 'nový' || s == 'zadáno') return 'task_status.assigned'.tr();
    return 'task_status.pending'.tr();
  }
}

/// Záložka Finance v detailu člena – peněženka (balance) + tlačítko Přejít do peněženky + výplaty/provize.
/// Celý obsah uzamčen při neaktivním modulu settlements (overlay + PremiumUpsellDialog).
class MemberFinanceTab extends ConsumerWidget {
  const MemberFinanceTab({super.key, required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlementsActive = isModuleActive(ref, 'settlements');
    if (!settlementsActive) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: GestureDetector(
          onTap: () => PremiumUpsellDialog.show(
            context,
            moduleKey: 'settlements',
            titleKey: 'admin.upsell.settlements.title',
            descriptionKey: 'admin.upsell.settlements.description',
          ),
          child: Opacity(
            opacity: 0.85,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 56, color: Colors.grey.shade500),
                    const SizedBox(height: 16),
                    Text(
                      'clients.finance_locked_message'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final profileId = member.profileId ?? member.id;
    final walletsAsync = ref.watch(employeeCashWalletsProvider);
    final financesAsync = ref.watch(memberFinancesProvider(profileId));

    final list = walletsAsync.valueOrNull ?? [];
    final walletRow = list.where((r) => r.profileId == profileId).firstOrNull;
    final balance = walletRow?.balance ?? 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'clients.tab_finance'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'admin.team_wallet_balance'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                formatWalletAmount(context, ref, balance),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                label: Text('admin.team_go_to_wallet'.tr()),
                onPressed: () {
                  Navigator.of(context).pop();
                  AdminTabScope.of(context)?.call(adminTabIndexFinance);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'clients.tab_finance'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: financesAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'clients.finance_empty'.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final row = list[index];
                  final taskTitle = (row['task_title'] as String?)?.trim() ?? '—';
                  final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
                  final status = (row['status'] as String?)?.trim().toLowerCase() ?? 'pending';
                  final createdAt = row['created_at'];
                  DateTime? date;
                  if (createdAt != null) {
                    if (createdAt is DateTime) date = createdAt;
                    else if (createdAt is String) date = DateTime.tryParse(createdAt);
                  }
                  final statusLabel = status == 'paid'
                      ? 'clients.finance_status_paid'.tr()
                      : 'clients.finance_status_pending'.tr();
                  final dateStr = date != null
                      ? DateFormat.yMd(context.locale.toString()).format(date.toLocal())
                      : '—';
                  final amountStr = formatWalletAmount(context, ref, amount);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(taskTitle, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '$dateStr • $statusLabel',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      trailing: Text(
                        amountStr,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                    const SizedBox(height: 16),
                    Text(
                      'common.error_with_message'.tr(namedArgs: {'message': err.toString()}),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}
