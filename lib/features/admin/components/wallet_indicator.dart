import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/components/wallet_topup_dialog.dart';
import 'package:falconest/features/admin/providers/wallet_provider.dart';

/// Indikátor zůstatku kreditů v horní navigační liště.
///
/// Zobrazuje aktuální balance z tenant_wallets v reálném čase. Kliknutím se
/// (v budoucnu) otevře dialog pro nákup kreditů (Top-Up).
class WalletIndicator extends ConsumerWidget {
  const WalletIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider);

    return Tooltip(
      message: 'admin.wallet_credits_tooltip'.tr(),
      child: InkWell(
        onTap: () => WalletTopUpDialog.show(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: balanceAsync.when(
            data: (balance) => _BalanceChip(balance: balance),
            loading: () => SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            // ignore: unnecessary_underscores – parametry error callback se nepoužívají
            error: (_, __) => Icon(Icons.help_outline, size: 22, color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}

/// Elegantní chip se zobrazením balance – ikona 💎 a číslo.
class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLow = balance < 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isLow ? Colors.orange : Colors.blueGrey).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isLow ? Colors.orange : Colors.blueGrey).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt,
            size: 18,
            color: isLow ? Colors.orange.shade700 : theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '$balance',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isLow ? Colors.orange.shade800 : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
