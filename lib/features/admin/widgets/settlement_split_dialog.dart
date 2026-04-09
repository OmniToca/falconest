import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/models/task_commission_model.dart';
import 'package:falconest/core/models/task_payout_model.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/settlements_provider.dart';

/// Příjemce provize – pouze člen personálu (profile_id).
///
/// PROČ: Dropdown pro příjemce provize zobrazuje výhradně personál – majitele apartmánů
/// a klienty (agentury/externí) jsme vyřadili, aby nedocházelo k míchání s CRM a provize
/// šly jen na členy týmu (referral, interní bonus).
class CommissionRecipient {
  const CommissionRecipient({
    required this.id,
    required this.name,
    required this.isEmployee,
  });

  final String id;
  final String name;
  /// true = Zaměstnanec (profile_id); v tomto dropdownu vždy true, zdroj je jen personál.
  final bool isEmployee;

  String displayLabel(BuildContext context) {
    final suffix = isEmployee
        ? 'admin.settlements.commission_recipient_employee'.tr()
        : 'admin.settlements.commission_recipient_agency'.tr();
    return '$name ($suffix)';
  }
}

/// Dialog pro rozpad vyúčtování – výplaty pracovníkům a provize externistovi.
///
/// PROČ: Admin zadává, kolik z celkové ceny úkolu jde pracovníkům a kolik provizí.
/// Zisk agentury se dopočítá dynamicky. Dělení nulou je ošetřeno.
class SettlementSplitDialog extends StatefulWidget {
  const SettlementSplitDialog({
    super.key,
    required this.ref,
    required this.task,
  });

  final WidgetRef ref;
  final TaskRow task;

  /// Otevře dialog nad aktuálním kontextem.
  static Future<void> show(
    BuildContext context, {
    required WidgetRef ref,
    required TaskRow task,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SettlementSplitDialog(ref: ref, task: task),
    );
  }

  @override
  State<SettlementSplitDialog> createState() => _SettlementSplitDialogState();
}

class _SettlementSplitDialogState extends State<SettlementSplitDialog> {
  final _workerPayoutController = TextEditingController(text: '0');
  final _commissionAmountController = TextEditingController(text: '0');
  CommissionRecipient? _selectedRecipient;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _workerPayoutController.addListener(_onValuesChanged);
    _commissionAmountController.addListener(_onValuesChanged);
  }

  @override
  void dispose() {
    _workerPayoutController.removeListener(_onValuesChanged);
    _commissionAmountController.removeListener(_onValuesChanged);
    _workerPayoutController.dispose();
    _commissionAmountController.dispose();
    super.dispose();
  }

  void _onValuesChanged() => setState(() {});

  /// Celková hodnota úkolu z metadata (amount_to_collect nebo service_price).
  double get _totalTaskPrice {
    final meta = widget.task.metadata;
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

  double get _workerPayout {
    final t = _workerPayoutController.text.trim();
    return double.tryParse(t) ?? 0;
  }

  double get _commissionAmount {
    if (_selectedRecipient == null) return 0;
    final t = _commissionAmountController.text.trim();
    return double.tryParse(t) ?? 0;
  }

  /// Zisk agentury = Celková cena - Výplaty - Provize. Nikdy záporné.
  double get _agencyMargin {
    final total = _totalTaskPrice;
    final payout = _workerPayout;
    final commission = _commissionAmount;
    final margin = total - payout - commission;
    return margin < 0 ? 0 : margin;
  }

  /// Počet pracovníků (assigned_to + assigned_user_ids). Min. 1 pro dělení.
  int get _workerCount {
    final ids = widget.task.allAssignees;
    return ids.isEmpty ? 1 : ids.length;
  }

  /// Částka na jednoho pracovníka. Dělení nulou ošetřeno.
  double get _perWorkerAmount {
    final c = _workerCount;
    if (c <= 0) return 0;
    return _workerPayout / c;
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.ref;
    final totalStr = formatWalletAmount(context, ref, _totalTaskPrice);
    final marginStr = formatWalletAmount(context, ref, _agencyMargin);
    final perWorkerStr = formatWalletAmount(context, ref, _perWorkerAmount);

    return AlertDialog(
      title: Text(
        'admin.settlements.split_dialog_title'.tr(
          namedArgs: {'taskName': widget.task.title},
        ),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Informační karta – kontext úkolu před zadáním částek (zamezení „slepému“ schvalování)
              _TaskInfoCard(task: widget.task),
              const SizedBox(height: 20),

              // Celková hodnota úkolu
              _RowLabel(
                label: 'admin.settlements.total_task_price'.tr(),
                value: totalStr,
              ),
              const SizedBox(height: 16),

              // Výplata pracovníkům
              TextField(
                controller: _workerPayoutController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'admin.settlements.worker_payout'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_workerCount > 1) ...[
                const SizedBox(height: 8),
                Text(
                  'admin.settlements.each_worker_gets'.tr(
                    namedArgs: {'amount': perWorkerStr},
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurface,
                      ),
                ),
              ],
              const SizedBox(height: 16),

              // Provize – dropdown výhradně personál (členové týmu); bez klientů a majitelů.
              FutureBuilder<List<TeamMember>>(
                future: ref.read(teamFullListProvider.future),
                builder: (context, snap) {
                  final teamMembers = snap.data ?? <TeamMember>[];
                  // PROČ: Zdroj dat je pouze personál – klienti (agentury, externí) a majitelé
                  // jsou vyřazeni. Zobrazujeme všechny členy týmu včetně z pozvánky; provize
                  // lze uložit jen těm s profile_id (task_commissions.profile_id FK na profiles).
                  final recipients = <CommissionRecipient>[
                    ...teamMembers
                        .where((m) => (m.profileId ?? '').trim().isNotEmpty)
                        .map(
                          (m) => CommissionRecipient(
                            id: m.profileId!,
                            name: m.name,
                            isEmployee: true,
                          ),
                        ),
                  ];

                  // PROČ: Při každém přebuildování FutureBuilderu vznikají nové instance
                  // CommissionRecipient. Dropdown porovnává value s položkami přes ==; jiná
                  // instance stejného příjemce by nebyla nalezena a zobrazilo by se prázdné/špatné.
                  // Bereme z aktuálního seznamu položku se stejným id – zobrazí se jméno (name).
                  final dropdownValue = _selectedRecipient == null
                      ? null
                      : recipients.where((r) => r.id == _selectedRecipient!.id).firstOrNull;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<CommissionRecipient?>(
                        initialValue: dropdownValue,
                        decoration: InputDecoration(
                          labelText: 'admin.settlements.select_commission_recipient'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<CommissionRecipient?>(
                            value: null,
                            child: Text('admin.settlements.none'.tr()),
                          ),
                          ...recipients.map(
                            (r) => DropdownMenuItem<CommissionRecipient?>(
                              value: r,
                              child: Text(r.displayLabel(context)),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _selectedRecipient = v;
                            if (v == null) {
                              _commissionAmountController.text = '0';
                            }
                          });
                        },
                      ),
                      if (_selectedRecipient != null) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _commissionAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'admin.settlements.commission_fee'.tr(),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Zisk agentury
              _RowLabel(
                label: 'admin.settlements.agency_margin'.tr(),
                value: marginStr,
                valueColor: context.customColors.success,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : () => _approve(context),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('admin.settlements.approve_button'.tr()),
        ),
      ],
    );
  }

  Future<void> _approve(BuildContext context) async {
    final ref = widget.ref;
    final workerCount = _workerCount;
    if (workerCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.settlements.empty_pending'.tr()),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final assignees = widget.task.allAssignees;
      if (assignees.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('admin.settlements.empty_pending'.tr()),
            ),
          );
        }
        return;
      }

      final totalPayout = _workerPayout;
      final count = assignees.length;
      final perWorker = count > 0 ? totalPayout / count : 0.0;

      final now = DateTime.now().toUtc();
      final payouts = assignees.map((profileId) {
        return TaskPayoutModel(
          id: '',
          tenantId: '',
          taskId: widget.task.id,
          profileId: profileId,
          amount: perWorker,
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        );
      }).toList();

      final commissions = <TaskCommissionModel>[];
      final recipient = _selectedRecipient;
      if (recipient != null && _commissionAmount > 0) {
        commissions.add(TaskCommissionModel(
          id: '',
          tenantId: '',
          taskId: widget.task.id,
          clientId: recipient.isEmployee ? null : recipient.id,
          profileId: recipient.isEmployee ? recipient.id : null,
          amount: _commissionAmount,
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ));
      }

      await approveSettlement(
        ref: ref,
        taskId: widget.task.id,
        payouts: payouts,
        commissions: commissions,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.settlements.approve_success'.tr()),
            backgroundColor: context.customColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'common.generic_error_user_friendly'.tr(),
            ),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

/// Read-only informační karta s kontextem úkolu – datum, typ služby, přiřazení, externí klient.
/// PROČ: Uživatel vidí před zadáním částek plný kontext, méně „slepého“ schvalování.
class _TaskInfoCard extends StatelessWidget {
  const _TaskInfoCard({required this.task});

  final TaskRow task;

  @override
  Widget build(BuildContext context) {
    final date = task.scheduledStart ?? task.dueDate;
    final dateStr = DateFormat('dd.MM.yyyy HH:mm', context.locale.toString()).format(date);
    final assigned = (task.assignedToName != null && task.assignedToName!.isNotEmpty)
        ? task.assignedToName!
        : 'common.placeholder_dash'.tr();
    final isExternal = task.clientId != null && task.clientId!.isNotEmpty;
    final externalStr = isExternal
        ? 'admin.settlements.info_external_client_yes'.tr()
        : 'admin.settlements.info_external_client_no'.tr();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'admin.settlements.info_card_title'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'admin.settlements.info_card_subtitle'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'admin.settlements.info_task_date'.tr(), value: dateStr),
          const SizedBox(height: 4),
          _InfoRow(label: 'admin.settlements.info_service_type'.tr(), value: task.taskType),
          const SizedBox(height: 4),
          _InfoRow(label: 'admin.settlements.info_assigned_to'.tr(), value: assigned),
          const SizedBox(height: 4),
          _InfoRow(label: 'admin.settlements.info_external_client'.tr(), value: externalStr),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurface,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
        ),
      ],
    );
  }
}
