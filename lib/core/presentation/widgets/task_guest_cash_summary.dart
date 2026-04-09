import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:falconest/core/theme/theme_ext.dart';

/// Jednotné zobrazení celkové hotovosti od hosta (agentura + průtok majiteli).
/// Admin: [compact]; check-in/transfer: [workerBanner]; check-out: [checkoutBanner].
enum TaskGuestCashSummaryVariant { compact, workerBanner, checkoutBanner }

class TaskGuestCashSummary extends StatelessWidget {
  const TaskGuestCashSummary({
    super.key,
    required this.agencyEur,
    required this.transitEur,
    required this.formatEurAmount,
    this.variant = TaskGuestCashSummaryVariant.compact,
  });

  final double agencyEur;
  final double transitEur;
  final String Function(double amountEur) formatEurAmount;
  final TaskGuestCashSummaryVariant variant;

  @override
  Widget build(BuildContext context) {
    final total = agencyEur + transitEur;
    if (total <= 0) return const SizedBox.shrink();

    final title = 'tasks.cash_total_from_guest'.tr();
    final agencyLine = 'tasks.cash_breakdown_agency'.tr();
    final transitLine = 'tasks.cash_breakdown_transit_owner'.tr();

    switch (variant) {
      case TaskGuestCashSummaryVariant.workerBanner:
        return _workerBanner(context, title, agencyLine, transitLine, total);
      case TaskGuestCashSummaryVariant.checkoutBanner:
        return _checkoutBanner(context, title, agencyLine, transitLine, total);
      case TaskGuestCashSummaryVariant.compact:
        return _compact(context, title, agencyLine, transitLine, total);
    }
  }

  Widget _compact(
    BuildContext context,
    String title,
    String agencyLine,
    String transitLine,
    double total,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.payments_outlined, size: 22, color: context.customColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatEurAmount(total),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: context.customColors.warning,
                    ),
                  ),
                  if (agencyEur > 0) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '$agencyLine: ${formatEurAmount(agencyEur)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  if (transitEur > 0) ...[
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '$transitLine: ${formatEurAmount(transitEur)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _workerBanner(
    BuildContext context,
    String title,
    String agencyLine,
    String transitLine,
    double total,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade400, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            formatEurAmount(total),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
          if (agencyEur > 0) ...[
            const SizedBox(height: 10),
            Text(
              '$agencyLine: ${formatEurAmount(agencyEur)}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
          if (transitEur > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$transitLine: ${formatEurAmount(transitEur)}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _checkoutBanner(
    BuildContext context,
    String title,
    String agencyLine,
    String transitLine,
    double total,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            formatEurAmount(total),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          if (agencyEur > 0) ...[
            const SizedBox(height: 10),
            Text(
              '$agencyLine: ${formatEurAmount(agencyEur)}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
          if (transitEur > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$transitLine: ${formatEurAmount(transitEur)}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }
}

/// Parsuje částku z JSON metadat úkolu; chybějící klíč = 0.
double taskMetadataAmountEur(Map<Object?, Object?> meta, String key) {
  if (!meta.containsKey(key)) return 0;
  final v = meta[key];
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}
