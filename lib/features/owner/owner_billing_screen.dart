import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/billing_pdf_service.dart';
import 'package:falconest/features/admin/providers/finance_billing_provider.dart';
import 'package:falconest/features/owner/providers/owner_billing_provider.dart';

/// Seznam zmražených vyúčtování majitele – Klientská zóna.
///
/// Data se načítají z tabulky billing_snapshots přes [ownerBillingSnapshotsProvider].
/// U každého měsíce majitel může stáhnout PDF report vygenerovaný on-demand
/// z uloženého snapshot_data.
class OwnerBillingScreen extends ConsumerWidget {
  const OwnerBillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotsAsync = ref.watch(ownerBillingSnapshotsProvider);

    return Scaffold(
      body: snapshotsAsync.when(
        data: (snapshots) => _buildContent(context, ref, snapshots),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                const SizedBox(height: 16),
                Text(
                  err.toString(),
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

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<BillingSnapshotModel> snapshots,
  ) {
    if (snapshots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'owner.billing_empty'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: snapshots.length,
      itemBuilder: (context, index) {
        return _SnapshotCard(
          snapshot: snapshots[index],
          onDownloadPdf: () => _onDownloadPdf(context, ref, snapshots[index]),
        );
      },
    );
  }

  Future<void> _onDownloadPdf(
    BuildContext context,
    WidgetRef ref,
    BillingSnapshotModel snapshot,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('owner.billing_pdf_generating'.tr())),
    );
    try {
      final group = BillingGroup.fromSnapshot(snapshot.snapshotData, snapshot.clientId);
      final currency = (snapshot.snapshotData['currency'] as String?) ?? 'EUR';
      await BillingPdfService.generateAndDownloadPdf(
        group,
        snapshot.billingPeriod,
        currency,
        externalDisplayName: 'admin.finance.billing_group_external'.tr(),
        payerLabels: {
          'owner': 'admin.finance.billing_payer_owner'.tr(),
          'guest': 'admin.finance.billing_payer_guest'.tr(),
          'client': 'admin.finance.billing_payer_client'.tr(),
        },
        footerLabels: {
          'report_title': 'admin.finance.billing_pdf_report_title'.tr(),
          'client_label': 'admin.finance.billing_client_label'.tr(),
          'guest_label': 'admin.finance.billing_guest_label'.tr(),
          'reservation_prefix': 'admin.finance.billing_reservation_prefix'.tr(),
          'standalone_services': 'admin.finance.billing_standalone_services'.tr(),
          'scheduled_label': 'admin.finance.billing_scheduled_label'.tr(),
          'completed_label': 'admin.finance.billing_completed_label'.tr(),
          'date_label': 'admin.finance.billing_date_label'.tr(),
          'fallback_client_name': 'admin.finance.billing_fallback_client_name'.tr(),
          'total_turnover': 'admin.finance.billing_total_turnover'.tr(),
          'paid_by_guests': 'admin.finance.billing_paid_by_guests'.tr(),
          'expenses_to_reimburse': 'admin.finance.billing_expenses_to_reimburse'.tr(),
          'expenses_section': 'admin.finance.billing_expenses_to_reimburse_section'.tr(),
          'monthly_management_fee': 'admin.finance.billing_monthly_management_fee'.tr(),
          'task_price_label': 'admin.finance.billing_task_price_label'.tr(),
          'task_guest_paid_label': 'admin.finance.billing_task_guest_paid_label'.tr(),
          'task_shortfall_due_label': 'admin.finance.billing_task_shortfall_due_label'.tr(),
          'final_pay': 'admin.finance.billing_final_owner_pay'.tr(),
          'payer': 'admin.finance.billing_payer'.tr(),
          'summary_section': 'admin.finance.billing_summary_section'.tr(),
          'services_breakdown': 'admin.finance.billing_services_breakdown'.tr(),
          'subtotal_per_reservation': 'admin.finance.billing_subtotal_per_reservation'.tr(),
          'turnover_short': 'admin.finance.billing_turnover_short'.tr(),
          'guest_paid_short': 'admin.finance.billing_guest_paid_short'.tr(),
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('owner.billing_pdf_success'.tr())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'common.error_with_message'.tr(namedArgs: {'message': e.toString()}),
            ),
          ),
        );
      }
    }
  }
}

/// Karta jednoho zmraženého vyúčtování – měsíc, částka, tlačítko PDF.
class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({
    required this.snapshot,
    required this.onDownloadPdf,
  });

  final BillingSnapshotModel snapshot;
  final VoidCallback onDownloadPdf;

  @override
  Widget build(BuildContext context) {
    final finalToInvoice = _toDouble(snapshot.snapshotData['final_to_invoice']) ?? 0.0;
    final currency = (snapshot.snapshotData['currency'] as String?) ?? 'EUR';
    final periodStr = DateFormat.yMMMM(context.locale.toString()).format(snapshot.billingPeriod);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          periodStr,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Text(
          '${finalToInvoice.toStringAsFixed(2)} $currency',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          tooltip: 'owner.billing_download_pdf'.tr(),
          onPressed: onDownloadPdf,
        ),
      ),
    );
  }
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
