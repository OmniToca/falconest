import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/admin/providers/wallet_provider.dart';

/// Balíček kreditů pro nákup – definice pro katalog.
class _WalletPackage {
  const _WalletPackage({
    required this.nameKey,
    required this.credits,
    required this.priceEur,
    this.isBestValue = false,
  });

  final String nameKey;
  final int credits;
  final int priceEur;
  final bool isBestValue;
}

/// Prémiový dialog pro dobití kreditů (Top-Up).
///
/// Zobrazuje aktuální zůstatek a katalog balíčků s tlačítky Koupit.
/// Stripe integrace bude doplněna v dalším kroku.
class WalletTopUpDialog extends ConsumerWidget {
  const WalletTopUpDialog({super.key});

  static const List<_WalletPackage> _packages = [
    _WalletPackage(nameKey: 'admin.wallet_package_starter', credits: 500, priceEur: 5),
    _WalletPackage(nameKey: 'admin.wallet_package_pro', credits: 5000, priceEur: 40, isBestValue: true),
    _WalletPackage(nameKey: 'admin.wallet_package_enterprise', credits: 15000, priceEur: 100),
  ];

  /// Otevře dialog pro dobití kreditů.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const WalletTopUpDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet, size: 28, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'admin.wallet_topup_title'.tr(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildBalanceSection(context, balanceAsync),
              const SizedBox(height: 24),
              Text(
                'admin.wallet_topup_packages_title'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: _packages.map((p) => _PackageCard(package: p, onBuy: () => _onBuy(context))).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSection(BuildContext context, AsyncValue<int> balanceAsync) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: balanceAsync.when(
        data: (balance) => Row(
          children: [
            Icon(Icons.bolt, size: 24, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'admin.wallet_topup_balance_label'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    '$balance',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        loading: () => Row(
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)),
            const SizedBox(width: 12),
            Text('admin.wallet_topup_balance_label'.tr(), style: theme.textTheme.bodyMedium),
          ],
        ),
        // ignore: unnecessary_underscores – parametry error callback se nepoužívají
        error: (_, __) => Text('admin.wallet_topup_balance_error'.tr(), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
      ),
    );
  }

  void _onBuy(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('admin.wallet_stripe_redirect'.tr()),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }
}

/// Karta balíčku – název, kredity, cena, tlačítko Koupit.
class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package, required this.onBuy});

  final _WalletPackage package;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPro = package.isBestValue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPro ? theme.colorScheme.primary : Colors.grey.shade300,
              width: isPro ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                if (isPro)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
                      ),
                      child: Text(
                        'admin.wallet_package_best_value'.tr(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, isPro ? 28 : 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        package.nameKey.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isPro ? theme.colorScheme.primary : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'admin.wallet_credits_format'.tr(namedArgs: {'count': '${package.credits}'}),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'admin.wallet_price_format'.tr(namedArgs: {'amount': '${package.priceEur}'}),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: onBuy,
                        child: Text('admin.wallet_btn_buy'.tr()),
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
}
