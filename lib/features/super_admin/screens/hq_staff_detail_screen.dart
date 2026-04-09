import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/utils/app_modal_utils.dart';
import 'package:falconest/features/super_admin/providers/hq_staff_provider.dart';
import 'package:falconest/features/super_admin/providers/hq_team_providers.dart';
import 'package:falconest/features/super_admin/screens/add_hq_absence_dialog.dart';
import 'package:falconest/features/super_admin/screens/add_hq_contract_dialog.dart';

/// Modální okno detailu člena HQ týmu – čtyři záložky: Profil, Smlouva, Portfolio, Dovolené.
///
/// PROČ: Stejný vzor jako Nastavení – otevírá se přes showAppModal, ne jako full-screen stránka.
/// Voláno z [HqTeamModal] po kliknutí na kartu pracovníka.
class HqStaffDetailModal {
  HqStaffDetailModal._();

  /// Otevře detail člena HQ týmu jako modální dialog.
  static Future<void> show(BuildContext context, WidgetRef ref, String profileId) {
    return showAppModal<void>(
      context: context,
      barrierLabel: 'super_admin.barrier_hq_staff_detail'.tr(),
      maxWidth: 900,
      maxHeightFraction: 0.85,
      child: _HqStaffDetailModalContent(profileId: profileId),
    );
  }
}

/// Vnitřní obsah modalu – hlavička, TabBar a TabBarView (bez Scaffold).
class _HqStaffDetailModalContent extends ConsumerStatefulWidget {
  const _HqStaffDetailModalContent({required this.profileId});

  final String profileId;

  @override
  ConsumerState<_HqStaffDetailModalContent> createState() => _HqStaffDetailModalContentState();
}

class _HqStaffDetailModalContentState extends ConsumerState<_HqStaffDetailModalContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(hqStaffListProvider);
    final staffName = listAsync.whenOrNull(
      data: (list) {
        final staff = list.where((e) => e.id == widget.profileId).firstOrNull;
        return staff?.displayName ?? widget.profileId;
      },
    ) ?? widget.profileId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  staffName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'common.cancel'.tr(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(text: 'super_admin.hq_staff_detail_tab_profile'.tr()),
              Tab(text: 'super_admin.hq_staff_detail_tab_contract'.tr()),
              Tab(text: 'super_admin.hq_staff_detail_tab_portfolio'.tr()),
              Tab(text: 'super_admin.hq_staff_detail_tab_absences'.tr()),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ProfileTab(profileId: widget.profileId),
              _ContractTab(profileId: widget.profileId),
              _PortfolioTab(profileId: widget.profileId),
              _AbsencesTab(profileId: widget.profileId),
            ],
          ),
        ),
      ],
    );
  }
}

/// Záložka Profil – jméno a role z HQ seznamu (read-only).
class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(hqStaffListProvider);
    return listAsync.when(
      data: (list) {
        final staff = list.where((e) => e.id == profileId).firstOrNull;
        if (staff == null) {
          return Center(child: Text('super_admin.tenant_not_found'.tr()));
        }
        final roleLabel = staff.role == 'super_admin'
            ? 'super_admin.hq_team_role_super_admin'.tr()
            : staff.role == 'account_manager'
                ? 'super_admin.hq_team_role_account_manager'.tr()
                : staff.role ?? 'common.placeholder_dash'.tr();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      roleLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text('super_admin.hq_team_load_error'.tr())),
    );
  }
}

/// Záložka Smlouva a odměny – aktivní smlouva nebo prázdný stav; tlačítka Přidat smlouvu a Ukončit.
class _ContractTab extends ConsumerWidget {
  const _ContractTab({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractAsync = ref.watch(hqStaffActiveContractProvider(profileId));
    return contractAsync.when(
      data: (contract) {
        final content = contract == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'super_admin.hq_staff_contract_empty'.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row(context, 'super_admin.hq_staff_contract_label_employment'.tr(), contract.employmentType == 'ico' ? 'super_admin.hq_staff_employment_ico'.tr() : 'super_admin.hq_staff_employment_hpp'.tr()),
                          if (contract.positionLabel != null && contract.positionLabel!.isNotEmpty)
                            _row(context, 'super_admin.hq_staff_contract_label_position'.tr(), contract.positionLabel!),
                          _row(context, 'super_admin.hq_staff_contract_label_validity'.tr(), contract.validTo != null
                              ? 'super_admin.hq_staff_contract_valid'.tr(namedArgs: {'from': DateFormat('d.M.yyyy').format(contract.validFrom), 'to': DateFormat('d.M.yyyy').format(contract.validTo!)})
                              : 'super_admin.hq_staff_contract_valid_open'.tr(namedArgs: {'from': DateFormat('d.M.yyyy').format(contract.validFrom)})),
                          if (contract.fixedSalaryMonthly != null)
                            _row(context, 'super_admin.hq_staff_contract_label_fixed_salary'.tr(), '${contract.fixedSalaryMonthly}'),
                          if (contract.bonusPerAcquiredAgency != null)
                            _row(context, 'super_admin.hq_staff_contract_label_bonus_acquired'.tr(), '${contract.bonusPerAcquiredAgency}'),
                          if (contract.commissionPercentManaged != null)
                            _row(context, 'super_admin.hq_staff_contract_label_commission'.tr(), '${contract.commissionPercentManaged}'),
                        ],
                      ),
                    ),
                  ),
                ],
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: content),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (contract != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _endContract(context, ref, profileId, contract.id),
                        icon: const Icon(Icons.event_busy, size: 18),
                        label: Text('super_admin.hq_contract_end_btn'.tr()),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: () => AddHqContractDialog.show(context, ref, profileId),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('super_admin.hq_contract_add_btn'.tr()),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text('super_admin.hq_team_load_error'.tr())),
    );
  }

  static Future<void> _endContract(BuildContext context, WidgetRef ref, String profileId, String contractId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('super_admin.hq_contract_end_btn'.tr()),
        content: Text('super_admin.hq_contract_end_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('common.cancel'.tr())),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('common.confirm'.tr())),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(hqStaffContractRepositoryProvider);
      await repo.endContract(contractId, DateTime.now());
      if (!context.mounted) return;
      ref.invalidate(hqStaffActiveContractProvider(profileId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.hq_contract_ended'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.generic_error_user_friendly'.tr()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
            ),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Záložka Portfolio – získané a spravované agentury ve dvou sekcích.
class _PortfolioTab extends ConsumerWidget {
  const _PortfolioTab({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioAsync = ref.watch(hqStaffPortfolioProvider(profileId));
    return portfolioAsync.when(
      data: (portfolio) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              context,
              'super_admin.hq_staff_portfolio_acquired'.tr(),
              portfolio.acquiredByMe,
            ),
            const SizedBox(height: 24),
            _section(
              context,
              'super_admin.hq_staff_portfolio_managed'.tr(),
              portfolio.managedByMe,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text('super_admin.hq_team_load_error'.tr())),
    );
  }

  Widget _section(BuildContext context, String title, List<HqPortfolioTenant> tenants) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (tenants.isEmpty)
              Text(
                'super_admin.hq_staff_portfolio_empty'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              )
            else
              ...tenants.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.business_outlined, size: 20, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Expanded(child: Text(t.name)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

/// Záložka Dovolené – seznam absencí (tenant_id IS NULL) pro tohoto HQ člena; tlačítko Přidat dovolenou.
class _AbsencesTab extends ConsumerWidget {
  const _AbsencesTab({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final absencesAsync = ref.watch(hqStaffAbsencesProvider(profileId));
    return absencesAsync.when(
      data: (list) {
        final content = list.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'super_admin.hq_staff_absences_empty'.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final a = list[index];
                  final fromStr = a.startDate != null ? DateFormat('d.M.yyyy').format(a.startDate!) : 'common.placeholder_dash'.tr();
                  final toStr = a.endDate != null ? DateFormat('d.M.yyyy').format(a.endDate!) : 'common.placeholder_dash'.tr();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(Icons.calendar_today_outlined, color: Theme.of(context).colorScheme.primary),
                      title: Text('$fromStr – $toStr'),
                      subtitle: a.reason != null && a.reason!.isNotEmpty ? Text(a.reason!) : null,
                    ),
                  );
                },
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: content),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: () => AddHqAbsenceDialog.show(context, ref, profileId),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('super_admin.hq_absence_add_btn'.tr()),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text('super_admin.hq_team_load_error'.tr())),
    );
  }
}
