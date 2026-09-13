import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/widgets/billing_payment_status_chip.dart';

/// Souhrn zápočtu hotovosti u faktury – uhrazeno / zbývá doplatit.
///
/// PROČ: Sdílené zobrazení v Admin fakturaci i Klientském portálu majitele.
class BillingOffsetPaymentSummary extends StatelessWidget {
  const BillingOffsetPaymentSummary({
    super.key,
    required this.finalToInvoice,
    required this.offsetAmount,
    required this.paymentStatus,
    required this.currency,
    this.compact = false,
  });

  final double finalToInvoice;
  final double offsetAmount;
  final String paymentStatus;
  final String currency;
  final bool compact;

  String get _normalizedStatus => paymentStatus.trim().toLowerCase();

  /// Faktura je uzavřená – bankou nebo plným zápočtem; neukazujeme „zbývá doplatit“.
  bool get _isFullySettled =>
      _normalizedStatus == 'paid' || _normalizedStatus == 'cash_offset';

  double get _remainingDue {
    if (_isFullySettled) return 0;
    if (offsetAmount <= 0) return finalToInvoice;
    return (finalToInvoice - offsetAmount).clamp(0.0, double.infinity);
  }

  bool get _showOffsetLine =>
      offsetAmount > 0 ||
      _normalizedStatus == 'partially_paid' ||
      _normalizedStatus == 'cash_offset';

  String _offsetDetailLine(String Function(double) fmt) {
    if (offsetAmount <= 0) {
      return 'owner.billing_offset_remaining_only'.tr(
        namedArgs: {'remaining': fmt(_remainingDue)},
      );
    }
    if (_normalizedStatus == 'paid') {
      return 'owner.billing_offset_applied_bank_rest'.tr(
        namedArgs: {'applied': fmt(offsetAmount)},
      );
    }
    if (_normalizedStatus == 'cash_offset') {
      return 'owner.billing_offset_applied_full'.tr(
        namedArgs: {'applied': fmt(offsetAmount)},
      );
    }
    return 'owner.billing_offset_applied_line'.tr(
      namedArgs: {
        'applied': fmt(offsetAmount),
        'remaining': fmt(_remainingDue),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showOffsetLine && offsetAmount <= 0) {
      return BillingPaymentStatusChip(
        paymentStatus: paymentStatus,
        compact: compact,
      );
    }

    final tt = Theme.of(context).textTheme;
    final cs = context.colors;
    String fmt(double v) => '${v.toStringAsFixed(2)} $currency';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BillingPaymentStatusChip(
          paymentStatus: paymentStatus,
          compact: compact,
        ),
        if (_showOffsetLine || offsetAmount > 0) ...[
          SizedBox(height: compact ? 4 : 6),
          Text(
            _offsetDetailLine(fmt),
            style: (compact ? tt.labelSmall : tt.bodySmall)?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
