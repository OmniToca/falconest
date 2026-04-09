import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/models/automation/automation_enums.dart';
import 'package:falconest/core/models/automation/tenant_message_log_row.dart';
import 'package:falconest/core/theme/app_spacing.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/features/admin/providers/automation_log_provider.dart';

/// Záložka / sekce „Historie komunikace“ u detailu rezervace v adminu.
///
/// PROČ: Dispečer vidí chronologicky, co už hostovi odešlo (SMS/WA/e-mail) včetně stavu odeslání.
class ReservationCommunicationHistorySection extends ConsumerWidget {
  const ReservationCommunicationHistorySection({
    super.key,
    required this.reservationId,
  });

  final String reservationId;

  static String _channelLabelKey(AutomationChannel c) {
    return switch (c) {
      AutomationChannel.email => 'communication.channel_email',
      AutomationChannel.sms => 'communication.channel_sms',
      AutomationChannel.whatsapp => 'communication.channel_whatsapp',
      AutomationChannel.internalPush => 'communication.channel_internal_push',
    };
  }

  static bool _isErrorStatus(String status) {
    final s = status.trim().toLowerCase();
    return s.contains('fail') || s.contains('error');
  }

  static String _preview(TenantMessageLogRow row) {
    if (row.direction == 'inbound') {
      final t = row.inboundText?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return row.contentSnapshot.trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reservationMessageLogProvider(reservationId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'admin.reservation_comm_log_error'.tr(),
          style: TextStyle(color: context.colors.error),
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              'admin.reservation_comm_log_empty'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: context.colors.outlineVariant),
              Builder(
                builder: (context) {
                  final row = rows[i];
                  final localTime = row.sentAt.toLocal();
                  final timeStr = DateFormat('dd.MM.yyyy HH:mm').format(localTime);
                  final channelStr = _channelLabelKey(row.channel).tr();
                  final err = _isErrorStatus(row.status);
                  final statusStr = err
                      ? 'admin.reservation_comm_log_status_error'.tr()
                      : 'admin.reservation_comm_log_status_sent'.tr();
                  final preview = _preview(row);
                  final short =
                      preview.length > 160 ? '${preview.substring(0, 160)}…' : preview;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                      horizontal: AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                timeStr,
                                style: context.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                channelStr,
                                style: context.textTheme.labelSmall,
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Icon(
                              err ? Icons.error_outline : Icons.check_circle_outline,
                              size: 18,
                              color: err
                                  ? context.colors.error
                                  : context.customColors.success,
                            ),
                            SizedBox(width: AppSpacing.xs),
                            Text(
                              statusStr,
                              style: context.textTheme.labelMedium?.copyWith(
                                color: err
                                    ? context.colors.error
                                    : context.customColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          short,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
