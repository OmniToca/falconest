import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/presentation/widgets/app_card.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/features/admin/finance_billing_screen.dart';
import 'package:falconest/features/admin/premium_upsell_dialog.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/widgets/wallet_detail_modal.dart';

/// Administrační obrazovka Zaměstnanecké pokladny – přehled dluhů zaměstnanců
/// a možnost potvrdit převzetí hotovosti v kanceláři (nulování kapsy).
class FinanceDashboardScreen extends ConsumerWidget {
  const FinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletsAsync = ref.watch(employeeCashWalletsProvider);
    final hasExport = isModuleActive(ref, 'finance_export');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'admin.finance.title'.tr(),
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'admin.finance.subtitle'.tr(),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          if (hasExport) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const FinanceBillingScreen(),
                              ),
                            );
                          } else {
                            PremiumUpsellDialog.show(
                              context,
                              moduleKey: 'finance_export',
                              titleKey: 'admin.module_finance_export_upsell_title',
                              descriptionKey: 'admin.module_finance_export_upsell_desc',
                            );
                          }
                        },
                        icon: Icon(hasExport ? Icons.receipt_long : Icons.lock_outline, size: 20),
                        label: Text('admin.finance.billing_btn'.tr()),
                      ),
                    ],
                  ),
                ],
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
                      SnackBar(content: Text('admin.finance.resolve_success'.tr())),
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
                        Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'admin.finance.empty'.tr(),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              final withDebt = wallets.where((w) => w.balance > 0).toList();
              final sorted = [...withDebt, ...wallets.where((w) => w.balance <= 0)];
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final row = sorted[index];
                    return _WalletCard(
                      row: row,
                      onTap: () {
                        WalletDetailModal.show(
                          context,
                          walletId: row.id,
                          workerName: row.workerName,
                        );
                      },
                      onReceiveCash: () => _showReceiveCashDialog(context, ref, row),
                    );
                  },
                  childCount: sorted.length,
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
      ),
    );
  }

  void _showReceiveCashDialog(BuildContext context, WidgetRef ref, EmployeeCashWalletRow row) {
    final formatted = NumberFormat.currency(
      locale: context.locale.toString(),
      symbol: '€',
      decimalDigits: 2,
    ).format(row.balance);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.finance.receive_confirm_title'.tr()),
        content: Text(
          'admin.finance.receive_confirm_message'.tr(
            namedArgs: {'balance': formatted},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final tenantId = ref.read(authNotifierProvider).tenantIdForData;
              final adminProfileId = ref.read(authNotifierProvider).state.profileId;
              if (tenantId == null || tenantId.isEmpty || adminProfileId == null || adminProfileId.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('admin.finance.receive_error_missing'.tr())),
                  );
                }
                return;
              }
              try {
                await CashWalletRepository.instance.receiveCashFromWorker(
                  walletId: row.id,
                  workerProfileId: row.profileId,
                  amountToClear: row.balance,
                  adminProfileId: adminProfileId,
                  tenantId: tenantId,
                );
                ref.invalidate(employeeCashWalletsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('admin.finance.receive_success'.tr())),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('admin.finance.receive_error'.tr())),
                  );
                }
              }
            },
            child: Text('admin.finance.receive_btn_confirm'.tr()),
          ),
        ],
      ),
    );
  }
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
              ...rows.map((row) => _FailedCashAlertCard(
                    row: row,
                    onResolve: () => onResolve(row.taskId),
                  )),
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
  });

  final FailedCashCollectionRow row;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final formattedAmount = NumberFormat.currency(
      locale: context.locale.toString(),
      symbol: '€',
      decimalDigits: 2,
    ).format(row.amountToCollect);

    final formattedDate = row.completedAt != null
        ? DateFormat.yMd(context.locale.toString()).format(row.completedAt!)
        : '—';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
        title: Text(
          'admin.finance.alert_task_info'.tr(
            namedArgs: {
              'taskTitle': row.taskTitle,
              'workerName': row.workerName,
            },
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('admin.finance.alert_amount'.tr(namedArgs: {'amount': formattedAmount})),
            Text(formattedDate, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
    required this.onTap,
    required this.onReceiveCash,
  });

  final EmployeeCashWalletRow row;
  final VoidCallback onTap;
  final VoidCallback onReceiveCash;

  @override
  Widget build(BuildContext context) {
    final hasDebt = row.balance > 0;
    final formatted = NumberFormat.currency(
      locale: context.locale.toString(),
      symbol: '€',
      decimalDigits: 2,
    ).format(row.balance);

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
                    Text(
                      row.workerName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: hasDebt ? Colors.red.shade900 : null,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatted,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: hasDebt ? Colors.red.shade800 : Colors.green.shade800,
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
