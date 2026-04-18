import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/admin_finance_providers.dart';
import 'package:falconest/features/admin/widgets/admin_owner_cash_request_detail_sheet.dart';
import 'package:falconest/features/owner/models/admin_owner_cash_disposition_row.dart';
import 'package:falconest/features/owner/repositories/owner_cash_disposition_repository.dart';

/// Přehled žádostí majitelů o výplatu / dispozici hotovosti (Finance → záložka).
///
/// PROČ: Dispečink má jednu frontu se stavem a poznámkami; klik otevře detail v bottom sheetu.
class AdminOwnerCashRequestsScreen extends ConsumerWidget {
  const AdminOwnerCashRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminOwnerCashRequestsProvider);
    final currency = ref.watch(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            'admin.finance.owner_cash_requests_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: async.when(
            data: (rows) {
              if (rows.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'admin.finance.owner_cash_requests_empty'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final row = rows[i];
                  return _OwnerCashRequestTile(
                    row: row,
                    currency: currency,
                    onTap: () => showAdminOwnerCashRequestDetailSheet(
                      context: context,
                      ref: ref,
                      row: row,
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'admin.finance.owner_cash_requests_load_error'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.error),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnerCashRequestTile extends StatelessWidget {
  const _OwnerCashRequestTile({
    required this.row,
    required this.currency,
    required this.onTap,
  });

  final AdminOwnerCashDispositionRow row;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = row.request;
    final dateStr =
        DateFormat.yMMMd(context.locale.toString()).add_jm().format(r.createdAt.toLocal());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: premiumCardDecoration(context),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.ownerDisplayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _StatusChip(status: r.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${r.amount.toStringAsFixed(2)} $currency · ${_typeLabel(context, r.dispositionType)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(BuildContext context, String type) {
    switch (type) {
      case OwnerCashDispositionTypeValues.bankTransfer:
        return 'admin.finance.owner_cash_type_bank'.tr();
      case OwnerCashDispositionTypeValues.invoiceCredit:
        return 'admin.finance.owner_cash_type_invoice'.tr();
      case OwnerCashDispositionTypeValues.vaultPickup:
        return 'admin.finance.owner_cash_type_vault'.tr();
      default:
        return type;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = _label(context);
    final Color bg;
    switch (status) {
      case OwnerCashDispositionStatusValues.pending:
        bg = context.colors.secondaryContainer;
        break;
      case OwnerCashDispositionStatusValues.approved:
        bg = context.colors.primaryContainer;
        break;
      case OwnerCashDispositionStatusValues.completed:
        bg = context.colors.tertiaryContainer;
        break;
      case OwnerCashDispositionStatusValues.partiallyCompleted:
        bg = context.colors.surfaceContainerHigh;
        break;
      case OwnerCashDispositionStatusValues.readyForPickup:
        bg = context.colors.primaryContainer;
        break;
      case OwnerCashDispositionStatusValues.rejected:
        bg = context.colors.errorContainer;
        break;
      default:
        bg = context.colors.surfaceContainerHighest;
        break;
    }

    return Chip(
      label: Text(label, style: Theme.of(context).textTheme.labelSmall),
      backgroundColor: bg,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  String _label(BuildContext context) {
    switch (status) {
      case OwnerCashDispositionStatusValues.pending:
        return 'admin.finance.owner_cash_status_pending'.tr();
      case OwnerCashDispositionStatusValues.approved:
        return 'admin.finance.owner_cash_status_approved'.tr();
      case OwnerCashDispositionStatusValues.completed:
        return 'admin.finance.owner_cash_status_completed'.tr();
      case OwnerCashDispositionStatusValues.partiallyCompleted:
        return 'admin.finance.owner_cash_status_partially_completed'.tr();
      case OwnerCashDispositionStatusValues.readyForPickup:
        return 'admin.finance.owner_cash_status_ready_for_pickup'.tr();
      case OwnerCashDispositionStatusValues.rejected:
        return 'admin.finance.owner_cash_status_rejected'.tr();
      default:
        return status;
    }
  }
}
