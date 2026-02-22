import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/super_admin/providers/billing_overview_provider.dart';

/// Modální okno Fakturace pro Super Admina – manuální přehled agentur a měsíčních částek.
///
/// Designově identické s [SuperAdminSettingsModal]: bílý podklad, zaoblené rohy, jemné stíny.
/// Obsahuje MRR widget a scrollovatelnou tabulku.
class SuperAdminBillingModal {
  SuperAdminBillingModal._();

  /// Otevře fakturační přehled jako modální dialog (blur, centrované okno).
  static Future<void> show(BuildContext hostContext) {
    return showGeneralDialog<void>(
      context: hostContext,
      barrierDismissible: true,
      barrierLabel: 'super_admin.barrier_billing'.tr(),
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (_, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: const _SuperAdminBillingContent(),
            ),
          ),
        );
      },
    );
  }
}

/// Vnitřní obsah modalu – nepřekonatelná struktura: Dialog → ConstrainedBox → Column → [A, B, C].
/// C je KRIZOVĚ obaleno v Flexible, aby nedocházelo k bílé obrazovce.
class _SuperAdminBillingContent extends ConsumerWidget {
  const _SuperAdminBillingContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(billingOverviewProvider);
    final currenciesAsync = ref.watch(currenciesProvider);
    final currencies = currenciesAsync.valueOrNull ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A) Hlavička – titulek + zavírací křížek
            _buildHeader(context),
            // B) Fialový Container s celkovým MRR
            overviewAsync.when(
              data: (rows) => _TotalMrrCard(totalMrr: rows.fold<double>(0, (sum, r) => sum + r.netTotalEur)),
              loading: () => _TotalMrrCard(totalMrr: 0),
              error: (err, stack) => _TotalMrrCard(totalMrr: 0),
            ),
            // C) Datová část – MUSÍ BÝT ve Flexible (zabraňuje bílé obrazovce)
            Flexible(
              child: overviewAsync.when(
                loading: () {
                  // Ošetření loading stavu – načítací kolečko MUSÍ být vidět
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                error: (err, _) {
                  // Ošetření error stavu – chybová hláška MUSÍ být vidět
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'super_admin.billing_load_error'.tr(),
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => ref.refresh(billingOverviewProvider),
                            child: Text('common.retry'.tr()),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                data: (tenants) {
                  if (tenants.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text('super_admin.billing_empty'.tr()),
                      ),
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hlavička sloupců
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text('super_admin.billing_col_agency'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(flex: 2, child: Text('super_admin.billing_col_month'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(flex: 3, child: Text('super_admin.billing_col_subscription_modules'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(flex: 1, child: Text('super_admin.billing_col_base'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(flex: 1, child: Text('super_admin.billing_col_discount'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(flex: 2, child: Text('super_admin.billing_col_due'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                            Expanded(flex: 1, child: Text('super_admin.billing_col_actions'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: tenants.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final r = tenants[index];
                              final theme = Theme.of(context);
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: theme.dividerColor)),
                                ),
                                child: _BillingDataRow(
                                  row: r,
                                  theme: theme,
                                  currencies: currencies,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'super_admin.billing_title'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Velký widget s celkovým MRR – CEO vidí na první pohled výdělky.
class _TotalMrrCard extends StatelessWidget {
  const _TotalMrrCard({required this.totalMrr});

  final double totalMrr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = totalMrr.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up, size: 48, color: theme.colorScheme.onPrimary.withValues(alpha: 0.9)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'super_admin.total_mrr'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$formatted €',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Jeden datový řádek fakturace – Row s Expanded buňkami odpovídajícími hlavičce.
class _BillingDataRow extends StatelessWidget {
  const _BillingDataRow({
    required this.row,
    required this.theme,
    required this.currencies,
  });

  final TenantBillingRow row;
  final ThemeData theme;
  final List<CurrencyRow> currencies;

  @override
  Widget build(BuildContext context) {
    final baseStr = currencies.isNotEmpty
        ? CurrencyService.formatPrice(row.grossTotalEur, row.currency, currencies)
        : '${row.grossTotalEur.toStringAsFixed(2)} €';
    final dueStr = currencies.isNotEmpty
        ? CurrencyService.formatPrice(row.netTotalEur, row.currency, currencies)
        : '${row.netTotalEur.toStringAsFixed(2)} €';
    final locale = context.locale.toString();
    final billingMonthStr = DateFormat.yMMMM(locale).format(DateTime.now());
    final discountStr = row.discountPercentage > 0 ? '${row.discountPercentage} %' : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              row.tenantName,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              billingMonthStr,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildInvoiceItemsColumn(),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(baseStr, style: theme.textTheme.bodyMedium),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(discountStr, style: theme.textTheme.bodyMedium),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dueStr, style: theme.textTheme.bodyMedium),
                  if (row.isInTrial) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'super_admin.billing_in_trial'.tr(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: IconButton(
              icon: const Icon(Icons.receipt),
              tooltip: 'super_admin.billing_mark_invoiced'.tr(),
              onPressed: () {
                // Strukturovaný payload pro budoucí export do Fakturoid/iDoklad.
                final invoicePayload = <String, dynamic>{
                  'tenant_id': row.tenantId,
                  'tenant_name': row.tenantName,
                  'currency': row.currency,
                  'gross_total': row.grossTotalEur,
                  'discount_percentage': row.discountPercentage,
                  'net_total': row.netTotalEur,
                  'items': row.invoiceItems
                      .map((i) => <String, dynamic>{
                            'name': i.name,
                            'price': i.priceEur,
                            'is_trial': i.isTrial,
                            'is_canceling': i.isCanceling,
                          })
                      .toList(),
                };
                debugPrint('BILLING PAYLOAD READY: $invoicePayload');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'super_admin.billing_export_ready'.tr(namedArgs: {'name': row.tenantName}),
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
                    elevation: 10,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Sloupec s rozpisem položek (invoiceItems) – název + cena, trial štítek.
  /// Expanded + TextOverflow.ellipsis zabraňuje přetečení dlouhých názvů do sousedních sloupců.
  Widget _buildInvoiceItemsColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in row.invoiceItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                      children: [
                        TextSpan(
                          text: item.name.startsWith('super_admin.') ? item.name.tr() : item.name,
                        ),
                        if (item.isCanceling)
                          TextSpan(
                            text: ' ${'super_admin.billing_item_canceling'.tr()}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (item.isTrial || item.isModuleTrial) ...[
                  const SizedBox(width: 8),
                  Text(
                    'super_admin.billing_item_trial'.tr(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange.shade700),
                  ),
                  const SizedBox(width: 8),
                  Text('0', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ] else ...[
                  const SizedBox(width: 8),
                  Text(
                    currencies.isNotEmpty
                        ? CurrencyService.formatPrice(item.priceEur, row.currency, currencies)
                        : '${item.priceEur.toStringAsFixed(2)} €',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
