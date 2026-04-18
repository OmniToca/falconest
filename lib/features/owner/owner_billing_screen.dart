import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/core/services/billing_pdf_service.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/finance_billing_provider.dart';
import 'package:falconest/features/owner/models/owner_cash_disposition_request.dart';
import 'package:falconest/features/owner/providers/owner_apartments_provider.dart';
import 'package:falconest/core/widgets/billing_payment_status_chip.dart';
import 'package:falconest/features/owner/providers/owner_billing_provider.dart';
import 'package:falconest/features/owner/providers/owner_cash_providers.dart';
import 'package:falconest/features/owner/providers/owner_company_expenses_provider.dart';
import 'package:falconest/features/owner/providers/owner_dashboard_metrics_provider.dart';
import 'package:falconest/features/owner/repositories/owner_cash_disposition_repository.dart';
import 'package:falconest/features/owner/utils/owner_vault_pickup_picker.dart';
import 'package:falconest/features/owner/widgets/owner_cash_disposition_dialog.dart';
import 'package:falconest/features/owner/widgets/owner_portal_ui.dart';

/// Otevře uložené PDF faktury z cloudu (Supabase Storage URL v [invoice_pdf_url]).
///
/// PROČ: Majitel má jedním klepnutím přístup k souboru, který nahrála agentura; záložně zůstává
/// generování PDF ze snapshotu.
Future<void> launchOwnerBillingStoredInvoicePdf(BuildContext context, String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('owner.billing_invoice_url_invalid'.tr())),
      );
    }
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('owner.detail_link_open_failed'.tr())),
    );
  }
}

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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
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
    final expensesAsync = ref.watch(ownerUninvoicedCompanyExpensesProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const _OwnerCashDispositionSection(),
        const SizedBox(height: 24),
        expensesAsync.when(
          data: (rows) => _OwnerCompanyExpensesSection(rows: rows),
          loading: () => const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(),
          ),
          error: (Object e, StackTrace st) => const SizedBox.shrink(),
        ),
        if (snapshots.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
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
          )
        else
          ...snapshots.map(
            (s) => _SnapshotCard(
              snapshot: s,
              onGeneratePdf: () => _onDownloadPdf(context, ref, s),
            ),
          ),
      ],
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
              'common.generic_error_user_friendly'.tr(),
            ),
          ),
        );
      }
    }
  }
}

/// Hotovost držená agenturou – zůstatek, nová žádost a historie.
///
/// PROČ: Vyúčtování je přirozené místo pro „peníze u nás“ vedle měsíčních liquidací.
class _OwnerCashDispositionSection extends ConsumerWidget {
  const _OwnerCashDispositionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(ownerAvailableBalanceProvider);
    final requestsAsync = ref.watch(ownerCashRequestsProvider);
    final currency = ref.watch(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'owner.cash_section_title'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'owner.cash_section_subtitle'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: premiumCardDecoration(context),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'owner.cash_balance_label'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              balanceAsync.when(
                data: (b) => Text(
                  '${b.toStringAsFixed(2)} $currency',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (_, _) => Text(
                  'common.generic_error_user_friendly'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.error),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => showOwnerCashDispositionDialog(context),
                icon: const Icon(Icons.payments_outlined),
                label: Text('owner.cash_request_new_btn'.tr()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'owner.cash_requests_title'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'owner.cash_requests_active_hint'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        requestsAsync.when(
          data: (requests) {
            final active = requests
                .where(
                  (r) =>
                      r.status != OwnerCashDispositionStatusValues.completed &&
                      r.status != OwnerCashDispositionStatusValues.rejected,
                )
                .toList();
            if (active.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  requests.isEmpty
                      ? 'owner.cash_requests_empty'.tr()
                      : 'owner.cash_requests_active_empty'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                ),
              );
            }
            return Column(
              children: active
                  .map((r) => _OwnerCashRequestTile(request: r, displayCurrency: currency))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Jeden řádek **aktivní** žádosti o dispozici (zbývá čerpání, stav, úprava termínu vyzvednutí).
///
/// PROČ: Majitel musí vidět rozdíl schválené částky a [usedAmount] u umoření; u vault_pickup
/// ve stavu pending smí měnit [pickup_date] přes stejné 48h pravidlo jako při vytvoření.
class _OwnerCashRequestTile extends ConsumerWidget {
  const _OwnerCashRequestTile({
    required this.request,
    required this.displayCurrency,
  });

  final OwnerCashDispositionRequest request;
  final String displayCurrency;

  static String _formatPickupShort(BuildContext context, DateTime utc) {
    final local = utc.toLocal();
    return DateFormat.yMMMd(context.locale.toString()).add_jm().format(local);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat.yMMMd(context.locale.toString()).format(request.createdAt.toLocal());
    final typeLabel = _trOwnerDispositionType(request.dispositionType);
    final statusLabel = _trOwnerDispositionStatus(request.status);
    final subtitle = 'owner.cash_request_row_subtitle'.tr(
      namedArgs: {
        'type': typeLabel,
        'amount': request.amount.toStringAsFixed(2),
        'currency': displayCurrency,
      },
    );

    final showUsageProgress = request.status == OwnerCashDispositionStatusValues.approved ||
        request.status == OwnerCashDispositionStatusValues.partiallyCompleted;
    final remaining = (request.amount - request.usedAmount)
        .clamp(0.0, double.infinity)
        .toDouble();
    final progress = request.amount > 1e-9
        ? (request.usedAmount / request.amount).clamp(0.0, 1.0)
        : 0.0;

    final showEditPickup = request.dispositionType == OwnerCashDispositionTypeValues.vaultPickup &&
        request.status == OwnerCashDispositionStatusValues.pending;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: premiumCardDecoration(context),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(dateStr),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle),
              if (request.dispositionType == OwnerCashDispositionTypeValues.vaultPickup &&
                  request.pickupDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'owner.cash_request_pickup_scheduled'.tr(
                    namedArgs: {'when': _formatPickupShort(context, request.pickupDate!)},
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                ),
              ],
              if (showUsageProgress) ...[
                const SizedBox(height: 8),
                Text(
                  'owner.cash_request_usage_line'.tr(
                    namedArgs: {
                      'approved': request.amount.toStringAsFixed(2),
                      'remaining': remaining.toStringAsFixed(2),
                      'currency': displayCurrency,
                    },
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ],
          ),
          isThreeLine: showUsageProgress ||
              (request.dispositionType == OwnerCashDispositionTypeValues.vaultPickup &&
                  request.pickupDate != null),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showEditPickup)
                IconButton(
                  tooltip: 'owner.cash_request_edit_pickup_tooltip'.tr(),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  onPressed: () async {
                    final utc = await pickOwnerVaultPickupDateTime(
                      context,
                      initialUtc: request.pickupDate,
                    );
                    if (utc == null || !context.mounted) return;
                    final auth = ref.read(authNotifierProvider);
                    final tid = auth.tenantIdForData;
                    final pid = auth.state.profileId;
                    if (tid == null || tid.isEmpty || pid == null || pid.isEmpty) return;
                    try {
                      await OwnerCashDispositionRepository.updateOwnerRequestPickupDate(
                        tenantId: tid,
                        ownerProfileId: pid,
                        requestId: request.id,
                        newPickupDate: utc,
                      );
                      ref.invalidate(ownerCashRequestsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('owner.cash_request_pickup_rescheduled'.tr())),
                        );
                      }
                    } on OwnerDispositionValidationException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.l10nKey.tr())),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('common.generic_error_user_friendly'.tr())),
                        );
                      }
                    }
                  },
                ),
              Chip(
                label: Text(statusLabel),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _trOwnerDispositionType(String type) {
  if (type == OwnerCashDispositionTypeValues.bankTransfer) {
    return 'owner.cash_disposition_type_bank_transfer'.tr();
  }
  if (type == OwnerCashDispositionTypeValues.invoiceCredit) {
    return 'owner.cash_disposition_type_invoice_credit'.tr();
  }
  if (type == OwnerCashDispositionTypeValues.vaultPickup) {
    return 'owner.cash_disposition_type_vault_pickup'.tr();
  }
  return type;
}

String _trOwnerDispositionStatus(String status) {
  if (status == OwnerCashDispositionStatusValues.pending) {
    return 'owner.cash_request_status_pending'.tr();
  }
  if (status == OwnerCashDispositionStatusValues.approved) {
    return 'owner.cash_request_status_approved'.tr();
  }
  if (status == OwnerCashDispositionStatusValues.rejected) {
    return 'owner.cash_request_status_rejected'.tr();
  }
  if (status == OwnerCashDispositionStatusValues.completed) {
    return 'owner.cash_request_status_completed'.tr();
  }
  if (status == OwnerCashDispositionStatusValues.partiallyCompleted) {
    return 'owner.cash_request_status_partially_completed'.tr();
  }
  if (status == OwnerCashDispositionStatusValues.readyForPickup) {
    return 'owner.cash_request_status_ready_for_pickup'.tr();
  }
  return status;
}

/// Firemní výdaje (COMPANY_EXPENSE) u vlastněných bytů – schválení majitelem do [metadata].
class _OwnerCompanyExpensesSection extends ConsumerWidget {
  const _OwnerCompanyExpensesSection({required this.rows});

  final List<OwnerCompanyExpenseRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'owner.company_expenses_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'owner.company_expenses_subtitle_uninvoiced'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'owner.company_expenses_uninvoiced_empty'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      );
    }

    final apartments = ref.watch(ownerApartmentsProvider).valueOrNull ?? [];
    final nameById = {for (final a in apartments) a.id: a.name};
    final currency = ref.watch(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
    final tenantId = ref.watch(authNotifierProvider).tenantIdForData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'owner.company_expenses_title'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'owner.company_expenses_subtitle_uninvoiced'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        ...rows.map((r) {
          final aptName = nameById[r.apartmentId] ?? r.apartmentId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: premiumCardDecoration(context),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  r.note?.isNotEmpty == true
                      ? r.note!
                      : 'owner.company_expense_no_note'.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${r.amount.toStringAsFixed(2)} $currency · $aptName',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: r.ownerApproved
                    ? Chip(
                        label: Text('owner.company_expense_approved'.tr()),
                        visualDensity: VisualDensity.compact,
                      )
                    : FilledButton.tonal(
                        onPressed: tenantId == null || tenantId.isEmpty
                            ? null
                            : () async {
                                try {
                                  await ownerApproveCompanyExpense(
                                    tenantId: tenantId,
                                    transactionId: r.id,
                                    currentMetadata: r.metadata,
                                  );
                                  ref.invalidate(ownerCompanyExpensesProvider);
                                  ref.invalidate(ownerUninvoicedCompanyExpensesProvider);
                                  ref.invalidate(ownerDashboardMetricsProvider);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('owner.company_expense_approved_snack'.tr()),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('common.generic_error_user_friendly'.tr()),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: Text('owner.company_expense_confirm'.tr()),
                      ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Karta jednoho zmraženého vyúčtování – přehledný řádek: období, částka, stav, akce PDF.
class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({
    required this.snapshot,
    required this.onGeneratePdf,
  });

  final BillingSnapshotModel snapshot;
  final Future<void> Function() onGeneratePdf;

  @override
  Widget build(BuildContext context) {
    final finalToInvoice = _toDouble(snapshot.snapshotData['final_to_invoice']) ?? 0.0;
    final currency = (snapshot.snapshotData['currency'] as String?) ?? 'EUR';
    final periodStr = DateFormat.yMMMM(context.locale.toString()).format(snapshot.billingPeriod);
    final storedInvoiceUrl = snapshot.invoicePdfUrl?.trim() ?? '';
    final hasStoredInvoice = storedInvoiceUrl.isNotEmpty;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasStoredInvoice
              ? () => launchOwnerBillingStoredInvoicePdf(context, storedInvoiceUrl)
              : null,
          borderRadius: BorderRadius.circular(kOwnerPortalCardRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: ownerPortalSectionDecoration(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.receipt_long_rounded, color: cs.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        periodStr,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${finalToInvoice.toStringAsFixed(2)} $currency',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      BillingPaymentStatusChip(paymentStatus: snapshot.paymentStatus),
                      if (hasStoredInvoice) ...[
                        const SizedBox(height: 6),
                        Text(
                          'owner.billing_open_stored_invoice_tooltip'.tr(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasStoredInvoice)
                      IconButton.filledTonal(
                        tooltip: 'owner.billing_open_stored_invoice_tooltip'.tr(),
                        onPressed: () => launchOwnerBillingStoredInvoicePdf(context, storedInvoiceUrl),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                      ),
                    IconButton.filledTonal(
                      tooltip: 'owner.billing_generate_snapshot_pdf_tooltip'.tr(),
                      onPressed: () => onGeneratePdf(),
                      icon: const Icon(Icons.description_outlined),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
