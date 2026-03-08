import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/utils/app_modal_utils.dart';
import 'package:falconest/features/super_admin/providers/agency_settlements_provider.dart';

/// Modální dialog „Zúčtování odměn“ – ruční schvalování provizí pro Lovce a Farmáře.
///
/// PROČ: Provize se zadávají ručně na základě výkazů práce, aby Super-Admin mohl zohlednit
/// reálný přínos a zabránilo se podvodům. Žádná plná automatizace – vždy schválení člověkem.
class AgencySettlementsModal {
  AgencySettlementsModal._();

  /// Používá [showAppModal] pro jednotný vizuál napříč aplikací.
  static Future<void> show(BuildContext hostContext) {
    return showAppModal<void>(
      context: hostContext,
      barrierLabel: 'super_admin.barrier_settlements'.tr(),
      maxWidth: 900,
      maxHeightPx: 850,
      child: _AgencySettlementsModalContent(hostContext: hostContext),
    );
  }
}

class _AgencySettlementsModalContent extends ConsumerStatefulWidget {
  const _AgencySettlementsModalContent({required this.hostContext});

  final BuildContext hostContext;

  @override
  ConsumerState<_AgencySettlementsModalContent> createState() => _AgencySettlementsModalContentState();
}

class _AgencySettlementsModalContentState extends ConsumerState<_AgencySettlementsModalContent> {
  /// Vybraný měsíc pro zúčtování (první den měsíce).
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(monthlyAgencySettlementsProvider(_selectedMonth));

    return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                Expanded(
                  child: cardsAsync.when(
                    data: (cards) {
                      if (cards.isEmpty) {
                        return Center(
                          child: Text(
                            'super_admin.settlements_empty'.tr(),
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: cards.length,
                        itemBuilder: (_, i) => _SettlementCard(
                          card: cards[i],
                          period: _selectedMonth,
                          onApproved: () => ref.invalidate(monthlyAgencySettlementsProvider(_selectedMonth)),
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'super_admin.settlements_load_error'.tr(),
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => ref.invalidate(monthlyAgencySettlementsProvider(_selectedMonth)),
                            child: Text('common.retry'.tr()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
  }

  Widget _buildHeader(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final monthStr = DateFormat.yMMMM(locale.toString()).format(_selectedMonth);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'super_admin.settlements_title'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'super_admin.settlements_prev_month'.tr(),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth.month == 1) {
                      _selectedMonth = DateTime(_selectedMonth.year - 1, 12, 1);
                    } else {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                    }
                  });
                },
              ),
              SizedBox(
                width: 160,
                child: Text(
                  monthStr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'super_admin.settlements_next_month'.tr(),
                onPressed: () {
                  setState(() {
                    if (_selectedMonth.month == 12) {
                      _selectedMonth = DateTime(_selectedMonth.year + 1, 1, 1);
                    } else {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'common.cancel'.tr(),
            onPressed: () => Navigator.of(widget.hostContext).pop(),
          ),
        ],
      ),
    );
  }
}

/// Jedna karta agentury: název + řádky Lovec / Farmář (jméno, odpracováno, částka, Schválit).
class _SettlementCard extends ConsumerStatefulWidget {
  const _SettlementCard({
    required this.card,
    required this.period,
    required this.onApproved,
  });

  final TenantSettlementCard card;
  final DateTime period;
  final VoidCallback onApproved;

  @override
  ConsumerState<_SettlementCard> createState() => _SettlementCardState();
}

class _SettlementCardState extends ConsumerState<_SettlementCard> {
  final _hunterAmountController = TextEditingController();
  final _farmerAmountController = TextEditingController();
  final _hunterFormKey = GlobalKey<FormState>();
  final _farmerFormKey = GlobalKey<FormState>();
  bool _hunterSaving = false;
  bool _farmerSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.card.hunter?.approvedAmount != null) {
      _hunterAmountController.text = widget.card.hunter!.approvedAmount!.toStringAsFixed(0);
    }
    if (widget.card.farmer?.approvedAmount != null) {
      _farmerAmountController.text = widget.card.farmer!.approvedAmount!.toStringAsFixed(0);
    }
  }

  @override
  void didUpdateWidget(_SettlementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.hunter?.approvedAmount != widget.card.hunter?.approvedAmount &&
        widget.card.hunter?.approvedAmount != null) {
      _hunterAmountController.text = widget.card.hunter!.approvedAmount!.toStringAsFixed(0);
    }
    if (oldWidget.card.farmer?.approvedAmount != widget.card.farmer?.approvedAmount &&
        widget.card.farmer?.approvedAmount != null) {
      _farmerAmountController.text = widget.card.farmer!.approvedAmount!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _hunterAmountController.dispose();
    _farmerAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.card.tenantName,
              style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            if (widget.card.hunter != null)
              _RoleRow(
                formKey: _hunterFormKey,
                label: 'super_admin.settlements_hunter_label'.tr(),
                info: widget.card.hunter!,
                amountController: _hunterAmountController,
                saving: _hunterSaving,
                onApprove: () => _approve(context, 'hunter', widget.card.hunter!, _hunterAmountController, (v) => setState(() => _hunterSaving = v)),
              ),
            if (widget.card.hunter != null && widget.card.farmer != null) const SizedBox(height: 12),
            if (widget.card.farmer != null)
              _RoleRow(
                formKey: _farmerFormKey,
                label: 'super_admin.settlements_farmer_label'.tr(),
                info: widget.card.farmer!,
                amountController: _farmerAmountController,
                saving: _farmerSaving,
                onApprove: () => _approve(context, 'farmer', widget.card.farmer!, _farmerAmountController, (v) => setState(() => _farmerSaving = v)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(
    BuildContext context,
    String roleType,
    RoleSettlementInfo info,
    TextEditingController amountController,
    void Function(bool) setSaving,
  ) async {
    // Validace se provádí i v TextFormField.validator; zde záloha pro případy bez Form.
    final amount = num.tryParse(amountController.text.trim());
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.settlements_amount_invalid'.tr()),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final repo = ref.read(agencyManagementSettlementsRepositoryProvider);
    final profileId = ref.read(authNotifierProvider).state.profileId;
    if (profileId == null || profileId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setSaving(true);
    try {
      await repo.upsertSettlement(
        profileId: info.profileId,
        tenantId: widget.card.tenantId,
        settlementPeriod: widget.period,
        roleType: roleType,
        amount: amount,
        approvedByProfileId: profileId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.settlements_approved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onApproved();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.settlements_approve_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setSaving(false);
    }
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.formKey,
    required this.label,
    required this.info,
    required this.amountController,
    required this.saving,
    required this.onApprove,
  });

  final GlobalKey<FormState> formKey;
  final String label;
  final RoleSettlementInfo info;
  final TextEditingController amountController;
  final bool saving;
  final VoidCallback onApprove;

  static String _formatWorked(int count, int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (m == 0) {
      return 'super_admin.settlements_worked_summary_h'.tr(
        namedArgs: {'count': '$count', 'hours': '$h'},
      );
    }
    return 'super_admin.settlements_worked_summary_hm'.tr(
      namedArgs: {'count': '$count', 'hours': '$h', 'min': '$m'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isApproved = info.settlementStatus == 'approved' || info.settlementStatus == 'paid';

    return Form(
      key: formKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.profileName,
                  style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.grey[900],
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatWorked(info.interventionsCount, info.totalMinutes),
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: TextFormField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              enabled: !isApproved,
              decoration: InputDecoration(
                labelText: '€',
                isDense: true,
                border: const OutlineInputBorder(),
                filled: isApproved,
                fillColor: Colors.green.shade50,
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'super_admin.settlements_amount_invalid'.tr();
                final n = num.tryParse(s);
                if (n == null || n < 0) return 'super_admin.settlements_amount_invalid'.tr();
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: FilledButton(
              onPressed: (isApproved || saving)
                  ? null
                  : () {
                      if (formKey.currentState?.validate() ?? true) onApprove();
                    },
            child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isApproved
                          ? 'super_admin.settlements_approved_short'.tr()
                          : 'super_admin.settlements_approve_btn'.tr(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
