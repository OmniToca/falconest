import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/legal_spain/legal_spain_constants.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/legal_spain/widgets/reservation_legal_section.dart';
import 'package:falconest/features/worker/providers/worker_detail_provider.dart';

/// U check-in úkolu doplní hosty na místě, pokud nedorazil veřejný formulář.
class WorkerLegalCheckinSection extends ConsumerWidget {
  const WorkerLegalCheckinSection({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isModuleActive(ref, kLegalSpainModuleKey)) {
      return const SizedBox.shrink();
    }
    final detail = ref.watch(workerTaskDetailProvider(taskId)).valueOrNull;
    if (detail == null || detail.taskType.toLowerCase() != 'check_in') {
      return const SizedBox.shrink();
    }

    return FutureBuilder<String?>(
      future: _reservationId(ref, taskId),
      builder: (context, snap) {
        final reservationId = snap.data;
        if (reservationId == null || reservationId.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'legal_spain.worker_fill_on_site'.tr(),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            ReservationLegalSection(
              reservationId: reservationId,
              apartmentId: detail.apartmentId,
              guestPhone: detail.guestPhone,
            ),
          ],
        );
      },
    );
  }

  Future<String?> _reservationId(WidgetRef ref, String taskId) async {
    try {
      final tenantId = ref.read(authNotifierProvider).tenantIdForData;
      final row = await SupabaseService.safeFrom('tasks', tenantId)
          .select('reservation_id')
          .eq('id', taskId)
          .maybeSingle();
      return row?['reservation_id'] as String?;
    } catch (e, st) {
      AppLogger.error('WorkerLegalCheckinSection._reservationId', e, st);
      return null;
    }
  }
}
