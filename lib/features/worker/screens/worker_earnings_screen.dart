import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/presentation/widgets/app_card.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/worker/providers/worker_earnings_provider.dart';

const _primaryBlue = Color(0xFF1565C0);

/// Obrazovka „Moje výdělky“ – read-only přehled výplat z úkolů.
///
/// Pracovník vidí, kolik si vydělal a které úkoly má zaplacené.
/// Dvě summary karty (Čeká na vyplacení / Již vyplaceno) a seznam jednotlivých výplat.
class WorkerEarningsScreen extends ConsumerWidget {
  const WorkerEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(myEarningsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('worker.earnings.title'.tr()),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: earningsAsync.when(
        data: (summary) {
          if (summary.rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
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
                      'worker.earnings.empty'.tr(),
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
          return CustomScrollView(
            slivers: [
              // Hlavička – Summary Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'worker.earnings.pending_total'.tr(),
                          amount: summary.pendingTotal,
                          formatAmount: (v) => formatWalletAmount(context, ref, v),
                          color: Colors.amber.shade700,
                          icon: Icons.schedule,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: 'worker.earnings.paid_total'.tr(),
                          amount: summary.paidTotal,
                          formatAmount: (v) => formatWalletAmount(context, ref, v),
                          color: Colors.green.shade700,
                          icon: Icons.check_circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Seznam výplat
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final row = summary.rows[index];
                    return _EarningsRowCard(
                      row: row,
                      formatAmount: (v) => formatWalletAmount(context, ref, v),
                      formatDate: (d) => DateFormat.yMd(Localizations.localeOf(context).toString()).format(d.toLocal()),
                    );
                  },
                  childCount: summary.rows.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
    );
  }
}

/// Jedna summary karta – Čeká na vyplacení nebo Již vyplaceno.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.formatAmount,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final String Function(double) formatAmount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatAmount(amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

/// Karta jedné výplaty – název úkolu, datum, částka, status badge.
class _EarningsRowCard extends StatelessWidget {
  const _EarningsRowCard({
    required this.row,
    required this.formatAmount,
    required this.formatDate,
  });

  final WorkerEarningsRow row;
  final String Function(double) formatAmount;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final statusColor = row.isPaid ? Colors.green.shade700 : Colors.orange.shade700;
    final statusLabel = row.isPaid
        ? 'worker.earnings.status_paid'.tr()
        : 'worker.earnings.status_pending'.tr();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.taskTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (row.completedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      formatDate(row.completedAt!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    formatAmount(row.amount),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    row.isPaid ? Icons.check_circle : Icons.schedule,
                    size: 14,
                    color: statusColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
