import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/features/owner/providers/owner_dashboard_metrics_provider.dart';
import 'package:falconest/features/owner/widgets/owner_report_issue_dialog.dart';

/// Klientský panel pro majitele bytů (role property_owner).
///
/// Úvodní obrazovka se souhrnem nadcházejících pobytů a nevyfakturovaných služeb,
/// odkazem na nahlášení závady.
class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apartments = ref.read(ownerApartmentsProvider).value ?? [];
    final profileId = ref.read(authNotifierProvider).state.profileId ?? '';
    final metricsAsync = ref.watch(ownerDashboardMetricsProvider);
    final currency = ref.watch(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'owner.dashboard_title'.tr(),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'owner.welcome_owner'.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              metricsAsync.when(
                data: (m) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DashboardMetricCard(
                        titleKey: 'owner.dashboard_upcoming_stays_title',
                        value: '${m.upcomingStaysNext14Days}',
                        subtitleKey: 'owner.dashboard_upcoming_stays_subtitle',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DashboardMetricCard(
                        titleKey: 'owner.dashboard_uninvoiced_services_title',
                        value:
                            '${m.uninvoicedOwnerServicesTotal.toStringAsFixed(2)} $currency',
                        subtitleKey: 'owner.dashboard_uninvoiced_services_subtitle',
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (Object e, StackTrace st) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
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
    );
  }
}

/// Jedna metrika na nástěnce – sjednocený vzhled s ostatními prémiovými kartami.
class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.titleKey,
    required this.value,
    required this.subtitleKey,
  });

  final String titleKey;
  final String value;
  final String subtitleKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: premiumCardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleKey.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitleKey.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
