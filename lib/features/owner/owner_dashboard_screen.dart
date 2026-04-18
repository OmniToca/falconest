import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/owner/owner_portal_tabs.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/providers/owner_cash_providers.dart';
import 'package:falconest/features/owner/providers/owner_dashboard_metrics_provider.dart';
import 'package:falconest/features/owner/widgets/owner_portal_ui.dart';
import 'package:falconest/features/owner/widgets/owner_report_issue_dialog.dart';
import 'package:falconest/features/owner/widgets/statistics/owner_cost_breakdown_chart.dart';

/// Klientský panel pro majitele bytů (role property_owner).
///
/// Úvodní obrazovka se souhrnem nadcházejících pobytů a nevyfakturovaných služeb,
/// odkazem na nahlášení závady. Vizuál je laděný jako **klientský produkt** – vzdušné
/// sekce, ikony a měkké plochy z [ColorScheme], ne jako interní admin nástroj.
class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apartments = ref.read(ownerApartmentsProvider).value ?? [];
    final profileId = ref.read(authNotifierProvider).state.profileId ?? '';
    final metricsAsync = ref.watch(ownerDashboardMetricsProvider);
    final currency = ref.watch(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLowest,
      body: SafeArea(
        child: ownerPortalConstrainBody(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'owner.dashboard_title'.tr(),
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'owner.welcome_owner'.tr(),
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                _OwnerAgencyCashCard(currency: currency),
                const SizedBox(height: 20),
                metricsAsync.when(
                  data: (m) => LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 640;
                      final cardStays = _DashboardMetricCard(
                        icon: Icons.event_available_rounded,
                        iconBg: context.colors.primaryContainer,
                        iconFg: context.colors.onPrimaryContainer,
                        titleKey: 'owner.dashboard_upcoming_stays_title',
                        value: '${m.upcomingStaysNext14Days}',
                        subtitleKey: 'owner.dashboard_upcoming_stays_subtitle',
                      );
                      final cardInvoice = _DashboardMetricCard(
                        icon: Icons.receipt_long_outlined,
                        iconBg: context.colors.secondaryContainer,
                        iconFg: context.colors.onSecondaryContainer,
                        titleKey: 'owner.dashboard_uninvoiced_services_title',
                        value:
                            '${m.uninvoicedOwnerServicesTotal.toStringAsFixed(2)} $currency',
                        subtitleKey: 'owner.dashboard_uninvoiced_services_subtitle',
                      );
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: cardStays),
                            const SizedBox(width: 16),
                            Expanded(child: cardInvoice),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          cardStays,
                          const SizedBox(height: 14),
                          cardInvoice,
                        ],
                      );
                    },
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (Object e, StackTrace st) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                const OwnerCostBreakdownDashboardCard(),
                const SizedBox(height: 28),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    alignment: Alignment.center,
                  ),
                  onPressed: () => openOwnerReportIssueDialog(
                    context,
                    apartments: apartments,
                    profileId: profileId,
                  ),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: Text('owner.report_issue_btn'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Výrazná karta hotovosti – primární akce přechodu do Vyúčtování.
class _OwnerAgencyCashCard extends ConsumerWidget {
  const _OwnerAgencyCashCard({required this.currency});

  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(ownerAvailableBalanceProvider);
    final c = context.colors;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(c.primaryContainer.withValues(alpha: 0.55), c.surface),
            Color.alphaBlend(c.tertiaryContainer.withValues(alpha: 0.35), c.surface),
          ],
        ),
        borderRadius: BorderRadius.circular(kOwnerPortalCardRadius),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: c.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'owner.dashboard_agency_cash_title'.tr(),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'owner.dashboard_agency_cash_subtitle'.tr(),
            style: context.textTheme.bodySmall?.copyWith(
              color: c.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          balanceAsync.when(
            data: (balance) => Text(
              '${balance.toStringAsFixed(2)} $currency',
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: c.onSurface,
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => Text(
              'common.generic_error_user_friendly'.tr(),
              style: context.textTheme.bodySmall?.copyWith(color: c.error),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              ref.read(ownerPortalTabIndexRequestProvider.notifier).state =
                  OwnerPortalTabIndex.billing;
            },
            child: Text('owner.dashboard_manage_cash_btn'.tr()),
          ),
        ],
      ),
    );
  }
}

/// Metrika – ikona v kolečku, čistá typografie.
class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.titleKey,
    required this.value,
    required this.subtitleKey,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String titleKey;
  final String value;
  final String subtitleKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ownerPortalSectionDecoration(context),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: iconBg,
            child: Icon(icon, color: iconFg, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            titleKey.tr(),
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitleKey.tr(),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
