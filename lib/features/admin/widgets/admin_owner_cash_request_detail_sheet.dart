import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/providers/tenant_currency_provider.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/admin_finance_providers.dart';
import 'package:falconest/features/owner/models/admin_owner_cash_disposition_row.dart';
import 'package:falconest/features/owner/repositories/owner_cash_disposition_repository.dart';

/// Bottom sheet: detail žádosti, změna stavu a doplnění poznámky dispečinku (append do [admin_notes]).
Future<void> showAdminOwnerCashRequestDetailSheet({
  required BuildContext context,
  required WidgetRef ref,
  required AdminOwnerCashDispositionRow row,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AdminOwnerCashRequestDetailBody(initialRow: row, parentRef: ref),
  );
}

class _AdminOwnerCashRequestDetailBody extends ConsumerStatefulWidget {
  const _AdminOwnerCashRequestDetailBody({
    required this.initialRow,
    required this.parentRef,
  });

  final AdminOwnerCashDispositionRow initialRow;
  final WidgetRef parentRef;

  @override
  ConsumerState<_AdminOwnerCashRequestDetailBody> createState() =>
      _AdminOwnerCashRequestDetailBodyState();
}

class _AdminOwnerCashRequestDetailBodyState extends ConsumerState<_AdminOwnerCashRequestDetailBody> {
  late String _status;
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialRow.request.status;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;

    setState(() => _saving = true);
    try {
      await OwnerCashDispositionRepository.updateRequestStatus(
        tenantId: tenantId,
        requestId: widget.initialRow.request.id,
        status: _status,
        appendAdminNote: _noteController.text.trim().isEmpty ? null : _noteController.text,
      );
      widget.parentRef.invalidate(adminOwnerCashRequestsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.finance.owner_cash_detail_save_success'.tr())),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.finance.owner_cash_detail_save_error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.initialRow.request;
    final currency = ref.watch(currentTenantCurrencyProvider).valueOrNull ?? 'EUR';
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final dateStr =
        DateFormat.yMMMd(context.locale.toString()).add_jm().format(r.createdAt.toLocal());

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'admin.finance.owner_cash_detail_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _DetailLine(
              label: 'admin.finance.owner_cash_col_owner'.tr(),
              value: widget.initialRow.ownerDisplayName,
            ),
            if (widget.initialRow.ownerEmail != null) ...[
              const SizedBox(height: 8),
              _DetailLine(
                label: 'admin.finance.owner_cash_detail_email'.tr(),
                value: widget.initialRow.ownerEmail!,
              ),
            ],
            const SizedBox(height: 8),
            _DetailLine(
              label: 'admin.finance.owner_cash_detail_amount'.tr(),
              value: '${r.amount.toStringAsFixed(2)} $currency',
            ),
            const SizedBox(height: 8),
            _DetailLine(
              label: 'admin.finance.owner_cash_detail_type'.tr(),
              value: _typeLabel(r.dispositionType),
            ),
            const SizedBox(height: 8),
            _DetailLine(
              label: 'admin.finance.owner_cash_detail_created'.tr(),
              value: dateStr,
            ),
            const SizedBox(height: 16),
            Text(
              'admin.finance.owner_cash_detail_notes_thread'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.outlineVariant),
              ),
              child: Text(
                (r.adminNotes == null || r.adminNotes!.trim().isEmpty)
                    ? 'admin.finance.owner_cash_detail_notes_empty'.tr()
                    : r.adminNotes!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'admin.finance.owner_cash_detail_status_label'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _status,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: OwnerCashDispositionStatusValues.pending,
                      child: Text('admin.finance.owner_cash_status_pending'.tr()),
                    ),
                    DropdownMenuItem(
                      value: OwnerCashDispositionStatusValues.approved,
                      child: Text('admin.finance.owner_cash_status_approved'.tr()),
                    ),
                    DropdownMenuItem(
                      value: OwnerCashDispositionStatusValues.completed,
                      child: Text('admin.finance.owner_cash_status_completed'.tr()),
                    ),
                    DropdownMenuItem(
                      value: OwnerCashDispositionStatusValues.partiallyCompleted,
                      child: Text(
                        'admin.finance.owner_cash_status_partially_completed'.tr(),
                      ),
                    ),
                    DropdownMenuItem(
                      value: OwnerCashDispositionStatusValues.readyForPickup,
                      child: Text(
                        'admin.finance.owner_cash_status_ready_for_pickup'.tr(),
                      ),
                    ),
                    DropdownMenuItem(
                      value: OwnerCashDispositionStatusValues.rejected,
                      child: Text('admin.finance.owner_cash_status_rejected'.tr()),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _status = v);
                        },
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'admin.finance.owner_cash_detail_new_note_label'.tr(),
                hintText: 'admin.finance.owner_cash_detail_new_note_hint'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              enabled: !_saving,
            ),
            const SizedBox(height: 8),
            Text(
              'admin.finance.owner_cash_detail_new_note_help'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.onPrimary,
                      ),
                    )
                  : Text('admin.finance.owner_cash_detail_save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
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

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
