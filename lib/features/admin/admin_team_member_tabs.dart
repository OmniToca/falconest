// Kontextové záložky Úkoly a Finance pro detail člena týmu (_EditMemberDialog).
// Design konzistentní s ClientDetailDialog a _EditApartmentDialog.

import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/presentation/widgets/app_card.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/calendar/providers/planning_calendar_provider.dart';

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
                    if (createdAt is DateTime) {
                      date = createdAt;
                    } else if (createdAt is String) {
                      date = DateTime.tryParse(createdAt);
                    }
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

/// Callback pro odpojení úkolů při schválení/uložení absence – volá se z [MemberAbsenceTab].
/// [memberName] – pro Soft-Unassign (unassigned_info.previous_name v DB).
typedef UnassignTasksForMemberCallback = Future<void> Function(
  String memberId, {
  DateTime? fromDate,
  DateTime? toDate,
  String? memberName,
});

/// Záložka Nepřítomnost v detailu člena – seznam absencí, Schválit/Zamítnout, přidání nové.
/// Stejná logika jako _AbsenceDialog v admin_team_screen; integrováno do Edit dialogu pro lepší UX.
class MemberAbsenceTab extends ConsumerStatefulWidget {
  const MemberAbsenceTab({
    super.key,
    required this.member,
    required this.onSaved,
    this.onUnassignTasksForMember,
  });

  final TeamMember member;
  final VoidCallback onSaved;
  final UnassignTasksForMemberCallback? onUnassignTasksForMember;

  @override
  ConsumerState<MemberAbsenceTab> createState() => _MemberAbsenceTabState();
}

class _MemberAbsenceTabState extends ConsumerState<MemberAbsenceTab> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  Future<void> _pickFromDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null && mounted) setState(() => _fromDate = d);
  }

  Future<void> _pickToDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null && mounted) setState(() => _toDate = d);
  }

  Future<void> _saveAbsence() async {
    if (_fromDate == null || _toDate == null) return;
    if (_toDate!.isBefore(_fromDate!)) return;
    if (_isSaving) return;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null) return;
    final isInvitation = widget.member.isFromInvitation;
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'start_date': _fromDate!.toIso8601String(),
      'end_date': _toDate!.toIso8601String(),
      'reason': _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      'status': staffAbsenceStatusApproved,
    };
    if (isInvitation) {
      payload['invitation_id'] = widget.member.invitationId ?? widget.member.id;
      payload['profile_id'] = null;
    } else {
      payload['profile_id'] = widget.member.profileId;
      payload['invitation_id'] = null;
    }

    setState(() => _isSaving = true);
    try {
      await SupabaseService.safeFrom('staff_absences', tenantId).insert(payload);
      if (!mounted) return;
      ref.invalidate(staffAbsencesProvider);
      final memberId = widget.member.profileId ?? widget.member.id;
      await widget.onUnassignTasksForMember?.call(memberId, fromDate: _fromDate, toDate: _toDate, memberName: widget.member.name);
      if (!mounted) return;
      widget.onSaved();
      _reasonController.clear();
      setState(() {
        _fromDate = null;
        _toDate = null;
        _isSaving = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _approveAbsence(StaffAbsence a) async {
    if (a.startDate == null || a.endDate == null) return;
    setState(() => _isSaving = true);
    try {
      await SupabaseService.client
          .from('staff_absences')
          .update({'status': staffAbsenceStatusApproved})
          .eq('id', a.id);
      if (!mounted) return;
      ref.invalidate(staffAbsencesProvider);
      final memberId = widget.member.profileId ?? widget.member.id;
      await widget.onUnassignTasksForMember?.call(memberId, fromDate: a.startDate, toDate: a.endDate, memberName: widget.member.name);
      if (!mounted) return;
      ref.invalidate(adminTasksProvider);
      ref.invalidate(planningCalendarAllTasksProvider);
      ref.invalidate(planningCalendarAllTasksForMonthProvider);
      setState(() => _isSaving = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _rejectAbsence(StaffAbsence a) async {
    setState(() => _isSaving = true);
    try {
      await SupabaseService.client
          .from('staff_absences')
          .update({'status': staffAbsenceStatusRejected})
          .eq('id', a.id);
      if (!mounted) return;
      ref.invalidate(staffAbsencesProvider);
      setState(() => _isSaving = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.error_with_message'.tr(namedArgs: {'message': e.toString()})),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final absencesAsync = ref.watch(staffAbsencesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'admin.absence_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: absencesAsync.when(
              data: (all) {
                final list = all.where((a) => a.belongsTo(widget.member)).toList();
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'admin.absence_empty_list'.tr(),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      else
                        ...list.map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${a.startDate != null ? _formatDate(a.startDate!) : '–'} – ${a.endDate != null ? _formatDate(a.endDate!) : '–'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (a.isPending)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: Text(
                                              'admin.absence_status_pending'.tr(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange.shade800,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (a.reason != null && a.reason!.isNotEmpty)
                                      Text(
                                        a.reason!,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                    if (a.isPending) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: _isSaving ? null : () => _rejectAbsence(a),
                                            child: Text('admin.absence_reject'.tr()),
                                          ),
                                          const SizedBox(width: 8),
                                          FilledButton(
                                            onPressed: _isSaving ? null : () => _approveAbsence(a),
                                            child: Text('admin.absence_approve'.tr()),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'admin.absence_add'.tr(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickFromDate,
                                    icon: const Icon(Icons.calendar_today, size: 18),
                                    label: Text(
                                      _fromDate == null
                                          ? 'admin.absence_from'.tr()
                                          : _formatDate(_fromDate!),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickToDate,
                                    icon: const Icon(Icons.calendar_today, size: 18),
                                    label: Text(
                                      _toDate == null
                                          ? 'admin.absence_to'.tr()
                                          : _formatDate(_toDate!),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _reasonController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.notes_outlined),
                                labelText: 'admin.absence_reason_hint'.tr(),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey.shade300)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey.shade300)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isSaving || _fromDate == null || _toDate == null
                            ? null
                            : _saveAbsence,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add, size: 20),
                        label: Text('common.save'.tr()),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text('common.error'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
