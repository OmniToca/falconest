import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/admin/screens/admin_owner_cash_requests_screen.dart';
import 'package:falconest/features/admin/screens/admin_settlements_screen.dart';
import 'package:falconest/features/admin/screens/finance_billing_screen.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/admin/providers/finance_tab_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/widgets/wallet_detail_modal.dart';

/// Administrační obrazovka Finance – Zaměstnanecká pokladna a Vyúčtování.
///
/// Dvě záložky: Peněženky (dluhy zaměstnanců) a Vyúčtování (fronta ke schválení).
class FinanceDashboardScreen extends ConsumerStatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  ConsumerState<FinanceDashboardScreen> createState() =>
      _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends ConsumerState<FinanceDashboardScreen>
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
    final walletsAsync = ref.watch(employeeCashWalletsProvider);
    ref.watch(
      activeModuleKeysProvider,
    ); // Rebuild při aktivaci/deaktivaci modulů
    final hasExport = isModuleActive(ref, 'finance_export');
    final hasSettlements = isModuleActive(ref, 'settlements');
    final requestedSubTab = ref.watch(financeRequestedSubTabProvider);
    if (requestedSubTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (requestedSubTab >= 0 &&
            requestedSubTab < _tabController.length &&
            _tabController.index != requestedSubTab) {
          _tabController.animateTo(requestedSubTab);
        }
        ref.read(financeRequestedSubTabProvider.notifier).state = null;
      });
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hlavička – obecný název "Přehled financí"
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Text(
              'admin.finance.dashboard_title'.tr(),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          // TabBar: Zaměstnanecká pokladna | Vyúčtování | Podklady pro fakturaci
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: [
              Tab(text: 'admin.finance.title'.tr()),
              Tab(child: _SettlementsTabLabel(isActive: hasSettlements)),
              Tab(child: _FinanceExportTabLabel(isActive: hasExport)),
              Tab(text: 'admin.finance.owner_cash_requests_tab'.tr()),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _WalletsTabContent(walletsAsync: walletsAsync),
                hasSettlements
                    ? const AdminSettlementsScreen()
                    : _SettlementsLockedPlaceholder(),
                hasExport
                    ? const FinanceBillingContent(inDialog: false)
                    : _FinanceExportLockedPlaceholder(),
                const AdminOwnerCashRequestsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Label záložky Podklady pro fakturaci – zobrazí ikonu zámečku, pokud modul není aktivní.
class _FinanceExportTabLabel extends StatelessWidget {
  const _FinanceExportTabLabel({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('admin.menu_finance_export'.tr()),
        if (!isActive) ...[
          const SizedBox(width: 6),
          Icon(Icons.lock, size: 14, color: Colors.grey.shade600),
        ],
      ],
    );
  }
}

/// Label záložky Vyúčtování – zobrazí ikonu zámečku, pokud modul není aktivní.
class _SettlementsTabLabel extends StatelessWidget {
  const _SettlementsTabLabel({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('admin.settlements.menu_title'.tr()),
        if (!isActive) ...[
          const SizedBox(width: 6),
          Icon(Icons.lock, size: 14, color: Colors.grey.shade600),
        ],
      ],
    );
  }
}

/// Placeholder pro zamčenou záložku Podklady pro fakturaci – prémiová funkce.
class _FinanceExportLockedPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock, size: 64, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Text(
              'admin.module_finance_export_upsell_title'.tr(),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'admin.module_finance_export_upsell_desc'.tr(),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                PremiumUpsellDialog.show(
                  context,
                  moduleKey: 'finance_export',
                  titleKey: 'admin.module_finance_export_upsell_title',
                  descriptionKey: 'admin.module_finance_export_upsell_desc',
                );
              },
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: Text('admin.upsell.unlock_trial_btn'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder pro zamčenou záložku Vyúčtování – prémiová funkce.
/// Obsahuje ikonu zámku, lákavý text a tlačítko pro otevření upsell dialogu.
class _SettlementsLockedPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock, size: 64, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            Text(
              'admin.upsell.settlements.title'.tr(),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'admin.upsell.settlements.description'.tr(),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                PremiumUpsellDialog.show(
                  context,
                  moduleKey: 'settlements',
                  titleKey: 'admin.upsell.settlements.title',
                  descriptionKey: 'admin.upsell.settlements.description',
                );
              },
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: Text('admin.upsell.unlock_trial_btn'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Obsah záložky Peněženky – původní obsah finance dashboardu.
class _WalletsTabContent extends ConsumerWidget {
  const _WalletsTabContent({required this.walletsAsync});

  final AsyncValue<List<EmployeeCashWalletRow>> walletsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        // Podnadpis – pouze pro záložku Zaměstnanecká pokladna
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              'admin.finance.subtitle'.tr(),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
            ),
          ),
        ),
        // Sekce kritických alertů: Zobrazuje úkoly, kde pracovník v terénu nepotvrdil výběr hotovosti.
        SliverToBoxAdapter(
          child: _FailedCashAlertsSection(
            onResolve: (taskId) async {
              try {
                await resolveFailedCashCollection(ref, taskId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('admin.finance.resolve_success'.tr()),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('admin.finance.resolve_error'.tr())),
                  );
                }
              }
            },
          ),
        ),
        walletsAsync.when(
          data: (wallets) {
            if (wallets.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'admin.finance.empty'.tr(),
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
            final withDebt = wallets.where((w) => w.balance > 0).toList();
            final sorted = [
              ...withDebt,
              ...wallets.where((w) => w.balance <= 0),
            ];
            return SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final row = sorted[index];
                return _WalletCard(
                  row: row,
                  formattedBalance: formatWalletAmount(
                    context,
                    ref,
                    row.balance,
                  ),
                  onTap: () {
                    WalletDetailModal.show(
                      context,
                      walletId: row.id,
                      workerName: row.workerName,
                    );
                  },
                  onReceiveCash: () => _showReceiveCashDialog(
                    context: context,
                    ref: ref,
                    row: row,
                  ),
                );
              }, childCount: sorted.length),
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
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'admin.finance.load_error'.tr(),
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

/// Zobrazí dialog pro převzetí hotovosti (částečný nebo celý výběr) – deleguje na WalletDetailModal.
void _showReceiveCashDialog({
  required BuildContext context,
  required WidgetRef ref,
  required EmployeeCashWalletRow row,
}) {
  WalletDetailModal.showReceiveCashDialog(context, ref, row);
}

/// Sekce kritických alertů: Zobrazuje úkoly, kde pracovník v terénu nepotvrdil výběr hotovosti.
/// Pokud je seznam prázdný, nevykresluje se.
class _FailedCashAlertsSection extends ConsumerWidget {
  const _FailedCashAlertsSection({required this.onResolve});

  final Future<void> Function(String taskId) onResolve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failedAsync = ref.watch(failedCashCollectionsProvider);

    return failedAsync.when(
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade400, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'admin.finance.alerts_title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
              ...rows.map(
                (r) => _FailedCashAlertCard(
                  row: r,
                  onResolve: () => onResolve(r.taskId),
                  formatAmount: (v) => formatWalletAmount(context, ref, v),
                  formatDate: (d) => formatTransactionDate(context, d),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// Karta jednoho alertu – úkol s nevybranou hotovostí.
class _FailedCashAlertCard extends StatelessWidget {
  const _FailedCashAlertCard({
    required this.row,
    required this.onResolve,
    required this.formatAmount,
    required this.formatDate,
  });

  final FailedCashCollectionRow row;
  final VoidCallback onResolve;
  final String Function(double) formatAmount;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final formattedAmount = formatAmount(row.amountToCollect);
    final formattedDate = row.completedAt != null
        ? formatDate(row.completedAt!)
        : 'common.placeholder_dash'.tr();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: premiumCardShell(
        context,
        child: ListTile(
          title: Text(
            'admin.finance.alert_task_info'.tr(
              namedArgs: {
                'taskTitle': row.taskTitle,
                'workerName': row.workerName,
              },
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'admin.finance.alert_amount'.tr(
                  namedArgs: {'amount': formattedAmount},
                ),
              ),
              Text(
                formattedDate,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          trailing: FilledButton(
            onPressed: onResolve,
            child: Text('admin.finance.btn_resolve'.tr()),
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}

/// Karta zaměstnance – zobrazuje jméno a zůstatek. Kliknutím otevře detail s historií.
/// Tlačítko „Převzít hotovost“ je přesunuto do detailu (Modal Bottom Sheet).
class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.row,
    required this.formattedBalance,
    required this.onTap,
    required this.onReceiveCash,
  });

  final EmployeeCashWalletRow row;
  final String formattedBalance;
  final VoidCallback onTap;
  final VoidCallback onReceiveCash;

  @override
  Widget build(BuildContext context) {
    final hasDebt = row.balance > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: premiumCardShell(
        context,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.workerName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hasDebt ? Colors.red.shade900 : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedBalance,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hasDebt
                            ? Colors.red.shade800
                            : Colors.green.shade800,
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
