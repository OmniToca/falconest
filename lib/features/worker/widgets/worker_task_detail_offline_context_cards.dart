import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:falconest/core/repositories/task/task_repository.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/worker/utils/worker_task_guest_context.dart';

/// Karty s daty staženými do Driftu – speciální požadavky, časy bytu, parkování,
/// termín splnění, kontext nepřiřazeného úkolu a údaje z rezervace (jazyk).
///
/// PROČ: Jednotné zobrazení nad type-specifickým obsahem, aby pracovník v terénu měl
/// všechny provozní informace na jednom místě bez duplikace v každé `*TaskScreen`.
class WorkerTaskDetailOfflineContextCards extends StatelessWidget {
  const WorkerTaskDetailOfflineContextCards({super.key, required this.detail});

  final WorkerTaskDetail detail;

  /// Zobrazitelný text z `unassigned_info` – pokud je JSON objekt, naformátuje se čitelně.
  static String? _formatUnassignedForUi(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final t = raw.trim();
    try {
      final d = jsonDecode(t);
      if (d is Map) {
        return const JsonEncoder.withIndent('  ').convert(d);
      }
    } catch (e, st) {
      AppLogger.error('WorkerTaskDetailOfflineContextCards: parsování unassigned_info JSON selhalo', e, st);
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');
    // PROČ: Úklid / údržba / prádelna nepotřebují „host-facing“ karty; snižuje to šum v UI.
    final showGuestReservationExtras =
        workerTaskTypeShowsGuestReservationDetailSections(detail.taskType);

    final unassigned = _formatUnassignedForUi(detail.unassignedInfo);
    if (unassigned != null && unassigned.isNotEmpty) {
      children.add(
        Card(
          margin: EdgeInsets.zero,
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.task_detail_offline_unassigned_title'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SelectableText(unassigned, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
    }

    if (detail.dueDate != null) {
      children.add(
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.event_available, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'worker.task_detail_offline_due_date_title'.tr(),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFmt.format(detail.dueDate!.toLocal()),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sr = detail.specialRequests?.trim();
    if (showGuestReservationExtras && sr != null && sr.isNotEmpty) {
      children.add(
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.task_detail_offline_special_requests_title'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(sr, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
    }

    if (showGuestReservationExtras && detail.hasLinkedReservation) {
      final lang = detail.guestLanguage?.trim();
      children.add(
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.task_detail_offline_reservation_info_title'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.language, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang != null && lang.isNotEmpty
                            ? 'worker.task_detail_offline_guest_language_value'
                                .tr(namedArgs: {'code': lang.toUpperCase()})
                            : 'worker.task_detail_offline_guest_language_missing'.tr(),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ci = detail.apartmentCheckInTime?.trim();
    final co = detail.apartmentCheckOutTime?.trim();
    final zone = detail.apartmentZoneId?.trim();
    final hasTimes = (ci != null && ci.isNotEmpty) || (co != null && co.isNotEmpty);
    final hasZone = zone != null && zone.isNotEmpty;
    if (showGuestReservationExtras && (hasTimes || hasZone)) {
      final lines = <Widget>[];
      if (ci != null && ci.isNotEmpty) {
        lines.add(Text(
          'worker.task_detail_offline_check_in_time'.tr(namedArgs: {'time': ci}),
          style: theme.textTheme.bodyMedium,
        ));
      }
      if (co != null && co.isNotEmpty) {
        lines.add(Text(
          'worker.task_detail_offline_check_out_time'.tr(namedArgs: {'time': co}),
          style: theme.textTheme.bodyMedium,
        ));
      }
      if (hasZone) {
        lines.add(Text(
          'worker.task_detail_offline_zone_id'.tr(namedArgs: {'id': zone}),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ));
      }

      children.add(
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'worker.task_detail_offline_apartment_times_title'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...lines,
              ],
            ),
          ),
        ),
      );
    }

    final park = detail.parkingInstructions?.trim();
    if (park != null && park.isNotEmpty) {
      children.add(
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_car, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'worker.task_detail_offline_parking_title'.tr(),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(park, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
