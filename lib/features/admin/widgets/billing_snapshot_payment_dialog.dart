import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/widgets/billing_offset_payment_summary.dart';
import 'package:falconest/features/admin/providers/finance_billing_provider.dart';
import 'package:falconest/features/owner/repositories/owner_cash_disposition_repository.dart';
import 'package:falconest/features/owner/services/owner_cash_offset_calculator.dart';

/// Výběr dispečera v dialogu stavu úhrady – bez ruční volby partially_paid / cash_offset.
enum BillingSnapshotPaymentChoice {
  unpaid,
  paid,
  applyCashFromDeposit,
}

/// Výsledek dialogu – null = zrušeno.
class BillingSnapshotPaymentDialogResult {
  const BillingSnapshotPaymentDialogResult(this.choice);
  final BillingSnapshotPaymentChoice choice;
}

/// Dialog úhrady zmraženého podkladu – náhled zápočtu ze zálohy majitele.
///
/// PROČ: Dispečer nevolí ručně cash_offset vs partially_paid; systém odvodí stav z poolu a faktury.
/// U [partially_paid] lze provést doplňkový zápočet doplatku z nové schválené žádosti.
Future<BillingSnapshotPaymentDialogResult?> showBillingSnapshotPaymentDialog({
  required BuildContext context,
  required BillingGroup group,
  required String tenantId,
  required String currencyCode,
}) {
  return showDialog<BillingSnapshotPaymentDialogResult>(
    context: context,
    builder: (ctx) => _BillingSnapshotPaymentDialog(
      group: group,
      tenantId: tenantId,
      currencyCode: currencyCode,
    ),
  );
}

class _BillingSnapshotPaymentDialog extends StatefulWidget {
  const _BillingSnapshotPaymentDialog({
    required this.group,
    required this.tenantId,
    required this.currencyCode,
  });

  final BillingGroup group;
  final String tenantId;
  final String currencyCode;

  @override
  State<_BillingSnapshotPaymentDialog> createState() =>
      _BillingSnapshotPaymentDialogState();
}

class _BillingSnapshotPaymentDialogState
    extends State<_BillingSnapshotPaymentDialog> {
  static const _eps = 1e-9;

  late BillingSnapshotPaymentChoice _selected;
  OwnerCashOffsetPlan? _offsetPlan;
  bool _loadingPlan = false;
  String? _planErrorKey;

  String get _paymentStatus =>
      widget.group.paymentStatus.trim().toLowerCase();

  double get _remainingInvoiceDue => (widget.group.finalToInvoice -
          widget.group.offsetAmount)
      .clamp(0.0, double.infinity);

  bool get _hasExistingOffset => widget.group.offsetAmount > _eps;

  /// Doplňkový zápočet – faktura je partially_paid a na faktuře zbývá doplatit.
  bool get _isSupplementOffset =>
      _paymentStatus == 'partially_paid' &&
      _hasExistingOffset &&
      _remainingInvoiceDue > _eps;

  /// První zápočet (neuhrazená faktura bez předchozího offsetu).
  bool get _canApplyFirstOffset =>
      !_hasExistingOffset &&
      _paymentStatus != 'paid' &&
      _paymentStatus != 'cash_offset' &&
      _paymentStatus != 'partially_paid' &&
      widget.group.finalToInvoice > _eps;

  bool get _canApplyCashOffset =>
      widget.group.groupKey != 'external' &&
      (_canApplyFirstOffset || _isSupplementOffset);

  @override
  void initState() {
    super.initState();
    _selected = _initialChoice();
    if (_selected == BillingSnapshotPaymentChoice.applyCashFromDeposit) {
      _loadOffsetPlan();
    }
  }

  BillingSnapshotPaymentChoice _initialChoice() {
    if (_paymentStatus == 'paid' || _paymentStatus == 'cash_offset') {
      return BillingSnapshotPaymentChoice.paid;
    }
    if (_paymentStatus == 'partially_paid') {
      return BillingSnapshotPaymentChoice.paid;
    }
    return BillingSnapshotPaymentChoice.unpaid;
  }

  Future<void> _loadOffsetPlan() async {
    if (!_canApplyCashOffset) return;
    setState(() {
      _loadingPlan = true;
      _planErrorKey = null;
      _offsetPlan = null;
    });
    try {
      final plan =
          await OwnerCashDispositionRepository.buildOffsetPlanForBillingClient(
        tenantId: widget.tenantId,
        billingClientId: widget.group.groupKey,
        invoiceDue: widget.group.finalToInvoice,
        existingOffsetAmount: widget.group.offsetAmount,
        currencyCode: widget.currencyCode,
      );
      if (!mounted) return;
      if (plan == null) {
        setState(() {
          _loadingPlan = false;
          _planErrorKey = 'admin.finance.billing_snapshot_offset_no_request';
        });
        return;
      }
      setState(() {
        _loadingPlan = false;
        _offsetPlan = plan;
        if (plan.blocked) {
          _planErrorKey = plan.blockReasonL10nKey;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPlan = false;
        _planErrorKey = 'admin.finance.billing_snapshot_update_error';
      });
    }
  }

  void _onChoiceChanged(BillingSnapshotPaymentChoice next) {
    setState(() => _selected = next);
    if (next == BillingSnapshotPaymentChoice.applyCashFromDeposit) {
      _loadOffsetPlan();
    }
  }

  String _fmt(double v) => '${v.toStringAsFixed(2)} ${widget.currencyCode}';

  String get _cashOffsetOptionLabel {
    if (_isSupplementOffset) {
      return 'admin.finance.billing_snapshot_payment_use_cash_deposit_supplement'
          .tr();
    }
    return 'admin.finance.billing_snapshot_payment_use_cash_deposit'.tr();
  }

  bool get _confirmEnabled {
    if (_selected == BillingSnapshotPaymentChoice.applyCashFromDeposit) {
      if (_loadingPlan || _offsetPlan == null) return false;
      return !_offsetPlan!.blocked && _offsetPlan!.amountToApply > _eps;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final tt = Theme.of(context).textTheme;
    final g = widget.group;

    return AlertDialog(
      title: Text('admin.finance.billing_snapshot_payment_dialog_title'.tr()),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_hasExistingOffset) ...[
                BillingOffsetPaymentSummary(
                  finalToInvoice: g.finalToInvoice,
                  offsetAmount: g.offsetAmount,
                  paymentStatus: g.paymentStatus,
                  currency: widget.currencyCode,
                ),
                const SizedBox(height: 12),
                if (_isSupplementOffset)
                  Text(
                    'admin.finance.billing_snapshot_offset_supplement_hint'.tr(
                      namedArgs: {
                        'remaining': _fmt(_remainingInvoiceDue),
                      },
                    ),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                const SizedBox(height: 16),
              ],
              Text(
                'admin.finance.billing_snapshot_payment_field_label'.tr(),
                style: tt.labelLarge,
              ),
              const SizedBox(height: 8),
              if (_paymentStatus != 'cash_offset')
                RadioListTile<BillingSnapshotPaymentChoice>(
                  value: BillingSnapshotPaymentChoice.unpaid,
                  groupValue: _selected,
                  onChanged: (v) {
                    if (v != null) _onChoiceChanged(v);
                  },
                  title: Text('owner.billing_payment_status_unpaid'.tr()),
                  contentPadding: EdgeInsets.zero,
                ),
              RadioListTile<BillingSnapshotPaymentChoice>(
                value: BillingSnapshotPaymentChoice.paid,
                groupValue: _selected,
                onChanged: (v) {
                  if (v != null) _onChoiceChanged(v);
                },
                title: Text('owner.billing_payment_status_paid'.tr()),
                contentPadding: EdgeInsets.zero,
              ),
              if (_canApplyCashOffset)
                RadioListTile<BillingSnapshotPaymentChoice>(
                  value: BillingSnapshotPaymentChoice.applyCashFromDeposit,
                  groupValue: _selected,
                  onChanged: (v) {
                    if (v != null) _onChoiceChanged(v);
                  },
                  title: Text(_cashOffsetOptionLabel),
                  contentPadding: EdgeInsets.zero,
                ),
              if (_selected ==
                  BillingSnapshotPaymentChoice.applyCashFromDeposit) ...[
                const SizedBox(height: 12),
                _buildOffsetPreview(context),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _confirmEnabled
              ? () => Navigator.of(context).pop(
                    BillingSnapshotPaymentDialogResult(_selected),
                  )
              : null,
          child: Text(_confirmButtonLabel),
        ),
      ],
    );
  }

  String get _confirmButtonLabel {
    if (_selected != BillingSnapshotPaymentChoice.applyCashFromDeposit) {
      return 'common.save'.tr();
    }
    if (_offsetPlan == null) return 'common.save'.tr();
    if (_isSupplementOffset) {
      return 'admin.finance.billing_snapshot_offset_confirm_supplement'.tr();
    }
    if (_offsetPlan!.isPartial) {
      return 'admin.finance.billing_snapshot_offset_confirm_partial'.tr();
    }
    return 'common.save'.tr();
  }

  Widget _buildOffsetPreview(BuildContext context) {
    final cs = context.colors;
    final tt = Theme.of(context).textTheme;
    final invoice = widget.group.finalToInvoice;
    final priorOffset = widget.group.offsetAmount;

    if (_loadingPlan) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_planErrorKey != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.error.withValues(alpha: 0.4)),
        ),
        child: Text(
          _planErrorKey!.tr(),
          style: tt.bodyMedium?.copyWith(color: cs.error),
        ),
      );
    }

    final plan = _offsetPlan;
    if (plan == null) return const SizedBox.shrink();

    final isPartial = plan.isPartial;
    final warningColor = isPartial ? cs.tertiary : cs.primary;
    final invoiceRemainingBefore =
        math.max(0.0, invoice - priorOffset);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPartial
              ? cs.tertiary.withValues(alpha: 0.55)
              : cs.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _previewRow(
            context,
            'admin.finance.billing_snapshot_offset_preview_invoice'.tr(),
            _fmt(invoice),
          ),
          if (priorOffset > _eps) ...[
            const SizedBox(height: 6),
            _previewRow(
              context,
              'admin.finance.billing_snapshot_offset_preview_already_applied'
                  .tr(),
              _fmt(priorOffset),
            ),
            const SizedBox(height: 6),
            _previewRow(
              context,
              'admin.finance.billing_snapshot_offset_preview_balance_due'.tr(),
              _fmt(invoiceRemainingBefore),
            ),
          ],
          const SizedBox(height: 6),
          _previewRow(
            context,
            'admin.finance.billing_snapshot_offset_preview_pool'.tr(),
            _fmt(plan.ownerPool),
            valueColor: plan.ownerPool < invoiceRemainingBefore ? cs.error : null,
          ),
          const SizedBox(height: 6),
          _previewRow(
            context,
            'admin.finance.billing_snapshot_offset_preview_request'.tr(),
            _fmt(plan.requestRemaining),
          ),
          const Divider(height: 20),
          if (isPartial) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: warningColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'admin.finance.billing_snapshot_offset_insufficient_for_full'
                        .tr(),
                    style: tt.bodyMedium?.copyWith(
                      color: warningColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          _previewRow(
            context,
            'admin.finance.billing_snapshot_offset_preview_apply'.tr(),
            _fmt(plan.amountToApply),
            valueColor: cs.primary,
            bold: true,
          ),
          const SizedBox(height: 6),
          _previewRow(
            context,
            'admin.finance.billing_snapshot_offset_preview_remaining'.tr(),
            _fmt(plan.remainingInvoiceDue),
          ),
          if (priorOffset > _eps) ...[
            const SizedBox(height: 6),
            _previewRow(
              context,
              'admin.finance.billing_snapshot_offset_preview_total_offset'.tr(),
              _fmt(priorOffset + plan.amountToApply),
              bold: true,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            isPartial
                ? 'owner.billing_payment_status_partially_paid'.tr()
                : 'owner.billing_payment_status_cash_offset'.tr(),
            style: tt.labelMedium?.copyWith(
              color: warningColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: tt.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
