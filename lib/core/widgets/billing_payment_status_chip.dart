import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Štítek stavu úhrady u řádku zmraženého vyúčtování (`billing_snapshots.payment_status`).
///
/// PROČ: Stejné barvy a překladové klíče jako v Klientském portálu (`owner.billing_payment_status_*`),
/// aby majitel i dispečer viděli konzistentní sémantiku (uhrazeno / částečně / zápočet / neuhrazeno).
/// [compact] zmenší padding pro husté řádky (např. ExpansionTile v Adminu).
class BillingPaymentStatusChip extends StatelessWidget {
  const BillingPaymentStatusChip({
    super.key,
    required this.paymentStatus,
    this.compact = false,
  });

  final String paymentStatus;

  /// Menší varianta pro řádky s mástem místem (Admin – podklady pro fakturaci).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = paymentStatus.trim().toLowerCase();
    late final Color fg;
    late final Color outline;
    late final String labelKey;
    switch (s) {
      case 'paid':
        fg = const Color(0xFF1B5E20);
        outline = const Color(0xFF81C784);
        labelKey = 'owner.billing_payment_status_paid';
        break;
      case 'partially_paid':
      case 'cash_offset':
        fg = const Color(0xFFE65100);
        outline = const Color(0xFFFFB74D);
        labelKey = s == 'cash_offset'
            ? 'owner.billing_payment_status_cash_offset'
            : 'owner.billing_payment_status_partially_paid';
        break;
      default:
        fg = const Color(0xFFB71C1C);
        outline = const Color(0xFFE57373);
        labelKey = 'owner.billing_payment_status_unpaid';
    }
    final hPad = compact ? 8.0 : 12.0;
    final vPad = compact ? 4.0 : 6.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: outline.withValues(alpha: 0.65)),
      ),
      child: Text(
        labelKey.tr(),
        style: (compact
                ? Theme.of(context).textTheme.labelMedium
                : Theme.of(context).textTheme.labelLarge)
            ?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
