import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Barevný chip stavu check-inu / SES.
class LegalStatusChip extends StatelessWidget {
  const LegalStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color bg;
    switch (status) {
      case 'reported':
        bg = cs.primaryContainer;
        break;
      case 'accepted':
      case 'queued':
        bg = cs.tertiaryContainer;
        break;
      case 'rejected':
      case 'timeout':
        bg = cs.errorContainer;
        break;
      default:
        bg = cs.surfaceContainerHighest;
    }
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: bg,
      label: Text('legal_spain.status_$status'.tr()),
    );
  }
}
