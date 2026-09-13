import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/models/cash_transaction_ui_model.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/widgets/falconest_network_image.dart';
import 'package:falconest/features/admin/widgets/wallet_detail_modal.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';
import 'package:falconest/features/worker/widgets/add_company_expense_dialog.dart';

const _primaryBlue = Color(0xFF1565C0);

/// Obrazovka „Moje Peněženka“ – přehled dlužného zůstatku a historie transakcí.
///
/// Pracovník vidí pouze vlastní peněženku a transakce (BEZPEČNOST: filtr podle profile_id).
/// Umožňuje zadávat firemní výdaje a sledovat výběry od hostů i odevzdání agentuře.
class WorkerWalletScreen extends ConsumerWidget {
  const WorkerWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(myCashWalletProvider);
    final transactionsAsync = ref.watch(myCashTransactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('worker.wallet_title'.tr()),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Hero sekce – zůstatek
          SliverToBoxAdapter(
            child: _BalanceHero(
              walletAsync: walletAsync,
              formatAmount: (v) => formatWalletAmount(context, ref, v),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton.icon(
                onPressed: () => AddCompanyExpenseDialog.show(context),
                icon: const Icon(Icons.receipt_long, size: 28),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'worker.wallet_add_expense'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          // Nadpis seznamu
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'worker.wallet_history'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
              ),
            ),
          ),
          // Seznam transakcí
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'admin.finance.wallet_history_empty'.tr(),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _TransactionTile(
                        transaction: transactions[index],
                        formatAmount: (v) => formatWalletAmount(context, ref, v),
                        formatDate: (d) => formatTransactionDateShort(context, d),
                        onReceiptTap: () => WalletDetailModal.showReceiptDialog(
                          context,
                          transactions[index].receiptImageUrl,
                        ),
                      );
                    },
                    childCount: transactions.length,
                  ),
                ),
              );
            },
            loading: () => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('common.loading'.tr())),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('common.generic_error_user_friendly'.tr()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero sekce s aktuálním zůstatkem.
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.walletAsync,
    required this.formatAmount,
  });

  final AsyncValue<EmployeeCashWalletRow?> walletAsync;
  final String Function(double) formatAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: walletAsync.when(
        data: (wallet) {
          final balance = wallet?.balance ?? 0.0;
          final formatted = formatAmount(balance);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'worker.wallet_current_balance'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatted,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: balance > 0
                      ? Colors.red.shade700
                      : (balance < 0 ? Colors.green.shade700 : Colors.black87),
                ),
              ),
            ],
          );
        },
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'worker.wallet_current_balance'.tr(),
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text('common.loading'.tr(), style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
        error: (err, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'worker.wallet_current_balance'.tr(),
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'common.generic_error_user_friendly'.tr(),
              style: const TextStyle(fontSize: 14, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

/// Řádek jedné transakce v historii – obohacený o kontext (apartmán, host) a náhled účtenky.
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.formatAmount,
    required this.formatDate,
    required this.onReceiptTap,
  });

  final CashTransactionUIModel transaction;
  final String Function(double) formatAmount;
  final String Function(DateTime) formatDate;
  final VoidCallback onReceiptTap;

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  @override
  Widget build(BuildContext context) {
    final type = transaction.transactionType ?? '';
    final amount = _toDouble(transaction.raw['amount']) ?? 0;
    final note = transaction.note;
    final receiptUrl = transaction.receiptImageUrl;
    final createdAt = transaction.createdAt;

    String dateStr = 'common.placeholder_dash'.tr();
    if (createdAt != null) {
      if (createdAt is DateTime) {
        dateStr = formatDate(createdAt.toLocal());
      } else if (createdAt is String) {
        final dt = DateTime.tryParse(createdAt);
        if (dt != null) {
          dateStr = formatDate(dt.toLocal());
        }
      }
    }

    String label;
    Color amountColor;
    final isPositive = amount > 0;
    final formattedAmount = isPositive
        ? '+ ${formatAmount(amount)}'
        : '- ${formatAmount(amount.abs())}';

    switch (type) {
      case 'COLLECTED_FROM_GUEST':
        label = 'worker.transaction_collected'.tr();
        amountColor = Colors.green.shade800;
        break;
      case 'HANDED_TO_AGENCY':
        label = 'worker.transaction_handed_over'.tr();
        amountColor = Colors.blueGrey.shade700;
        break;
      case 'COMPANY_EXPENSE':
        label = 'worker.transaction_expense'.tr();
        amountColor = Colors.red.shade700;
        break;
      default:
        label = type;
        amountColor = Colors.grey.shade800;
    }

    // Subtitle: pro COLLECTED_FROM_GUEST apartmán + host; pro klienta jméno + typ; pro ostatní poznámka.
    String? subtitleContext;
    if (transaction.hasClientContext &&
        (transaction.clientName != null && transaction.clientName!.isNotEmpty)) {
      final parts = <String>[];
      parts.add('${'admin.finance.transaction_client_label'.tr()}: ${transaction.clientName}');
      if (transaction.clientType != null && transaction.clientType!.isNotEmpty) {
        final t = transaction.clientType!.toLowerCase();
        final typeLabel = t == 'owner'
            ? 'clients.type_owner'.tr()
            : t == 'agency'
                ? 'clients.type_agency'.tr()
                : t == 'external'
                    ? 'clients.type_external'.tr()
                    : transaction.clientType;
        parts.add('($typeLabel)');
      }
      subtitleContext = parts.join(' ');
    } else if (type == 'COLLECTED_FROM_GUEST' && transaction.hasTaskContext) {
      final parts = <String>[];
      if (transaction.apartmentName != null && transaction.apartmentName!.isNotEmpty) {
        parts.add('${'admin.finance.transaction_apartment_label'.tr()}: ${transaction.apartmentName}');
      }
      if (transaction.guestName != null && transaction.guestName!.isNotEmpty) {
        parts.add('${'admin.finance.transaction_guest_label'.tr()}: ${transaction.guestName}');
      }
      if (parts.isNotEmpty) subtitleContext = parts.join('\n');
    } else if (type == 'COMPANY_EXPENSE' && note != null && note.isNotEmpty) {
      subtitleContext = note;
    }

    Widget? trailing;
    if (receiptUrl != null && receiptUrl.isNotEmpty) {
      trailing = GestureDetector(
        onTap: onReceiptTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: FalconestNetworkImage(
            imageUrl: receiptUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.receipt_long, size: 32),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              formattedAmount,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: amountColor,
                fontSize: 15,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subtitleContext != null && subtitleContext.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitleContext,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            Text(
              dateStr,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: trailing,
      ),
    );
  }
}
