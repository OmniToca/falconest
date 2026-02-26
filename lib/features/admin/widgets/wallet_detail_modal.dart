import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/cash_transaction_ui_model.dart';
import 'package:falconest/core/repositories/cash/cash_wallet_repository.dart';
import 'package:falconest/features/admin/providers/finance_cash_provider.dart';

/// Prémiový modální dialog detailu peněženky zaměstnance.
///
/// PROČ: Sjednocení designu s oknem Nastavení (SettingsModal) – centrované okno
/// s rozostřeným pozadím, animacemi Fade+Scale a identickým vizuálem (bílé pozadí,
/// zaoblené rohy 24, stín). Nahrazuje plnoobrazovkovou routu AdminWalletDetailScreen.
class WalletDetailModal {
  WalletDetailModal._();

  /// Otevře detail peněženky jako modální dialog – identická struktura jako [SettingsModal].
  ///
  /// PROČ: showGeneralDialog umožňuje custom transitionBuilder (blur, animace),
  /// zatímco showDialog má omezené možnosti. Klient vyžaduje stejný vizuál jako Nastavení.
  static Future<void> show(
    BuildContext context, {
    required String walletId,
    required String workerName,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'admin.finance.wallet_detail_title'
          .tr(namedArgs: {'name': workerName}),
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (_, animation, secondaryAnimation, child) {
        // PROČ: Sjednocení designu s oknem Nastavení pomocí BackdropFilter a animací.
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: _WalletDetailModalContent(
                walletId: walletId,
                workerName: workerName,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Otevře dialog s fotkou účtenky – [InteractiveViewer] proti RenderFlex Overflow.
  ///
  /// Sdíleno mezi Admin (detail peněženky) a Worker (moje peněženka).
  static void showReceiptDialog(BuildContext context, String? url) {
    if (url == null || url.trim().isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(ctx).size.width * 0.9,
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Stack(
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 64),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vnitřní obsah modalu – převzat z AdminWalletDetailScreen, struktura jako SettingsModal.
class _WalletDetailModalContent extends ConsumerWidget {
  const _WalletDetailModalContent({
    required this.walletId,
    required this.workerName,
  });

  final String walletId;
  final String workerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletFromList = ref.watch(employeeCashWalletsProvider).valueOrNull
        ?.where((w) => w.id == walletId)
        .firstOrNull;
    final row = walletFromList;
    final formatted = row != null
        ? NumberFormat.currency(
            locale: context.locale.toString(),
            symbol: '€',
            decimalDigits: 2,
          ).format(row.balance)
        : '—';
    final hasDebt = (row?.balance ?? 0) > 0;
    final displayName = (row?.workerName ?? workerName).trim().isNotEmpty
        ? (row?.workerName ?? workerName)
        : '—';

    // PROČ: Stejná vrstvená struktura jako SettingsModal – Center -> Material -> ConstrainedBox -> Container.
    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context, displayName),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hlavička – zůstatek
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatted,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: hasDebt
                                        ? Colors.red.shade800
                                        : Colors.green.shade800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Seznam transakcí
                      Expanded(
                        child: ref.watch(walletTransactionsProvider(walletId)).when(
                              data: (transactions) {
                                if (transactions.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'admin.finance.wallet_history_empty'.tr(),
                                      style: TextStyle(color: Colors.grey.shade600),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: transactions.length,
                                  itemBuilder: (context, index) {
                                    final t = transactions[index];
                                    return _TransactionTile(
                                      transaction: t,
                                      onReceiptTap: () =>
                                          WalletDetailModal.showReceiptDialog(
                                        context,
                                        t.receiptImageUrl,
                                      ),
                                    );
                                  },
                                );
                              },
                              loading: () =>
                                  const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Center(
                                    child: Text(
                                      'admin.finance.load_error'.tr(),
                                      style: TextStyle(color: Colors.red.shade700),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                            ),
                      ),
                      // Tlačítko Převzít hotovost
                      if (hasDebt && row != null)
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _showReceiveCashDialog(
                                  context,
                                  ref,
                                  row,
                                ),
                                icon: const Icon(Icons.handshake, size: 20),
                                label: Text('admin.finance.receive_btn'.tr()),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hlavička modalu – stejný layout jako SettingsModal: název vlevo, křížek vpravo.
  Widget _buildHeader(BuildContext context, String displayName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'admin.finance.wallet_detail_title'.tr(namedArgs: {'name': displayName}),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'common.cancel'.tr(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showReceiveCashDialog(
    BuildContext context,
    WidgetRef ref,
    EmployeeCashWalletRow row,
  ) {
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
              final adminProfileId =
                  ref.read(authNotifierProvider).state.profileId;
              if (tenantId == null ||
                  tenantId.isEmpty ||
                  adminProfileId == null ||
                  adminProfileId.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'admin.finance.receive_error_missing'.tr(),
                      ),
                    ),
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
                    SnackBar(
                      content: Text('admin.finance.receive_success'.tr()),
                    ),
                  );
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('admin.finance.receive_error'.tr()),
                    ),
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

/// Jedna transakce v seznamu – typ, částka, kontext (apartmán, host), poznámka, náhled účtenky.
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.onReceiptTap,
  });

  final CashTransactionUIModel transaction;
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

    String dateStr = '—';
    if (createdAt != null) {
      if (createdAt is DateTime) {
        dateStr = DateFormat.yMd(context.locale.toString())
            .add_Hm()
            .format(createdAt.toLocal());
      } else if (createdAt is String) {
        final dt = DateTime.tryParse(createdAt);
        if (dt != null) {
          dateStr = DateFormat.yMd(context.locale.toString())
              .add_Hm()
              .format(dt.toLocal());
        }
      }
    }

    String label;
    Color amountColor;
    final isPositive = amount > 0;
    final formattedAmount =
        '${isPositive ? '+' : ''} ${amount.toStringAsFixed(2)} €';

    switch (type) {
      case 'COLLECTED_FROM_GUEST':
        label = 'admin.finance.transaction_collected'.tr();
        amountColor = Colors.green.shade800;
        break;
      case 'HANDED_TO_AGENCY':
        label = 'admin.finance.transaction_handed'.tr();
        amountColor = Colors.grey.shade700;
        break;
      case 'COMPANY_EXPENSE':
        label = 'admin.finance.transaction_expense'.tr();
        amountColor = Colors.red.shade700;
        break;
      default:
        label = type;
        amountColor = Colors.grey.shade800;
    }

    String? subtitleContext;
    if (type == 'COLLECTED_FROM_GUEST' && transaction.hasTaskContext) {
      final parts = <String>[];
      if (transaction.apartmentName != null &&
          transaction.apartmentName!.isNotEmpty) {
        parts.add(
          '${'admin.finance.transaction_apartment_label'.tr()}: ${transaction.apartmentName}',
        );
      }
      if (transaction.guestName != null &&
          transaction.guestName!.isNotEmpty) {
        parts.add(
          '${'admin.finance.transaction_guest_label'.tr()}: ${transaction.guestName}',
        );
      }
      if (parts.isNotEmpty) subtitleContext = parts.join('\n');
    } else if (note != null && note.isNotEmpty) {
      subtitleContext = note;
    }

    Widget? trailing;
    if (receiptUrl != null && receiptUrl.isNotEmpty) {
      trailing = GestureDetector(
        onTap: onReceiptTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            receiptUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.receipt_long, size: 36),
          ),
        ),
      );
    }

    return ListTile(
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
            Text(
              subtitleContext,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          Text(
            dateStr,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
      trailing: trailing,
      isThreeLine: subtitleContext != null && subtitleContext.isNotEmpty,
    );
  }
}
