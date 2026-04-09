import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/services/absence_notification_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/worker/widgets/worker_absence_submit_outcome.dart';
import 'package:uuid/uuid.dart';

/// Web: pokus o přímý INSERT; při síťové chybě fronta mutací (bez Driftu).
Future<(WorkerAbsenceSubmitOutcome, String?)> submitWorkerAbsenceRequest({
  required WidgetRef ref,
  required String tenantId,
  required String profileId,
  required String userName,
  required DateTime startDate,
  required DateTime endDate,
  required String reasonKey,
}) async {
  final payload = <String, dynamic>{
    'id': const Uuid().v4(),
    'tenant_id': tenantId,
    'profile_id': profileId,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    'reason': reasonKey,
    'status': staffAbsenceStatusPending,
  };

  final formattedStart = DateFormat('dd.MM.yyyy').format(startDate);
  final formattedEnd = DateFormat('dd.MM.yyyy').format(endDate);

  try {
    await SupabaseService.safeFrom('staff_absences', tenantId).insert(payload);
    await AbsenceNotificationService.notifyAdminsAboutAbsenceRequest(
      tenantId: tenantId,
      userName: userName,
      formattedStart: formattedStart,
      formattedEnd: formattedEnd,
    );
    return (WorkerAbsenceSubmitOutcome.successOnline, null);
  } catch (e) {
    if (!kIsWeb && MutationQueueService.isNetworkError(e)) {
      await ref.read(mutationQueueServiceProvider).enqueueMutation(
            table: 'staff_absences',
            action: 'INSERT',
            payload: payload,
          );
      return (WorkerAbsenceSubmitOutcome.successQueuedOffline, null);
    }
    return (WorkerAbsenceSubmitOutcome.failure, e.toString());
  }
}
