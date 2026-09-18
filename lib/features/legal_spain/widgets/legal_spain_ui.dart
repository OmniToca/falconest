import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/presentation/widgets/modern_admin_panel.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/premium_card_decoration.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/widgets/app_empty_state.dart';
import 'package:falconest/features/legal_spain/models/guest_checkin.dart';
import 'package:falconest/features/legal_spain/widgets/legal_status_chip.dart';

/// Sdílený vizuál Legal Spain se zbytkem adminu (karty, empty, dialogy).
///
/// PROČ: První verze obrazovek použila surový AppBar + ListTile; Automatizace /
/// Komunikace mají headline v těle, [premiumCardShell] a [ModernAdminPanel].

/// Chyba načtení se stejným layoutem jako Nástěnka / Komunikace.
Widget legalSpainErrorState(BuildContext context, {required VoidCallback onRetry}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: AppSpacing.xxl, color: context.colors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            'common.generic_error_user_friendly'.tr(),
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onRetry,
            child: Text('common.retry'.tr()),
          ),
        ],
      ),
    ),
  );
}

/// Prázdný stav uprostřed záložky.
Widget legalSpainEmptyState({
  required IconData icon,
  required String title,
  String? subtitle,
  Widget? action,
}) {
  return Center(
    child: AppEmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
      action: action,
    ),
  );
}

/// Otevře široký editační panel (stejný dialog jako Apartmány / Rezervace).
Future<void> showLegalSpainPanel({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget>? actions,
  double maxWidth = 800,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => ModernAdminPanel(
      title: title,
      maxWidth: maxWidth,
      actions: actions,
      content: content,
    ),
  );
}

/// Karta pobytu / hosta v přehledu – [premiumCardShell] + avatar + status chip.
class LegalSpainStayCard extends StatelessWidget {
  const LegalSpainStayCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.status,
    this.leadingIcon = Icons.badge_outlined,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String? status;
  final IconData leadingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: premiumCardShell(
        context,
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: context.colors.primaryContainer,
            child: Icon(leadingIcon, color: context.colors.onPrimaryContainer),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle.trim().isEmpty
              ? null
              : Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: status != null
              ? LegalStatusChip(status: status!)
              : (onTap == null
                  ? null
                  : Icon(Icons.chevron_right, color: context.colors.onSurfaceVariant)),
        ),
      ),
    );
  }
}

/// Formát intervalu pobytu pro karty (lokální locale).
String legalSpainStayDates(BuildContext context, LegalComplianceRow row) {
  final df = DateFormat.yMMMd(context.locale.toString());
  final parts = [
    if (row.startDate != null) df.format(row.startDate!),
    if (row.endDate != null) df.format(row.endDate!),
  ];
  return parts.join(' – ');
}
