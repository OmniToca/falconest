import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/theme/theme_ext.dart';

/// Barevný chip stavu check-inu / SES – sémantika z [CustomColors], ne default Material Chip.
class LegalStatusChip extends StatelessWidget {
  const LegalStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cc = context.customColors;
    final cs = context.colors;
    final Color bg;
    final Color fg;
    switch (status) {
      case 'reported':
        bg = cc.successSubtle;
        fg = cc.success;
        break;
      case 'accepted':
      case 'queued':
        bg = cc.infoSubtle;
        fg = cc.info;
        break;
      case 'rejected':
      case 'timeout':
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        break;
      default:
        bg = cc.warningSubtle;
        fg = cc.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'legal_spain.status_$status'.tr(),
        style: context.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
