import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/worker/widgets/worker_absence_submit_outcome.dart';

/// Mobil: nejdřív Drift (`pending`), pak INSERT mutace se stejným UUID; server notifikace proběhne ve frontě.
///
/// PROČ: UI čte výhradně SQLite – řádek musí existovat před odesláním; Supabase se netlačí přímo z dialogu.
Future<(WorkerAbsenceSubmitOutcome, String?)> submitWorkerAbsenceRequest({
  required WidgetRef ref,
  required String tenantId,
  required String profileId,
  required String userName,
  required DateTime startDate,
  required DateTime endDate,
  required String reasonKey,
}) async {
  final id = const Uuid().v4();
  final startStr = startDate.toIso8601String();
  final endStr = endDate.toIso8601String();
  final payload = <String, dynamic>{
    'id': id,
    'tenant_id': tenantId,
    'profile_id': profileId,
    'start_date': startStr,
    'end_date': endStr,
    'reason': reasonKey,
    'status': staffAbsenceStatusPending,
  };

  try {
    final drift = ref.read(driftStaffAbsenceRepositoryProvider);
    await drift.insertPendingAbsence(
      supabaseId: id,
      tenantId: tenantId,
      profileId: profileId,
      startDate: startDate,
      endDate: endDate,
      reason: reasonKey,
      status: staffAbsenceStatusPending,
    );

    await ref.read(mutationQueueServiceProvider).enqueueMutation(
          table: 'staff_absences',
          action: 'INSERT',
          payload: payload,
          recordId: id,
        );

    // PROČ: Při dostupné síti odešleme hned; při chybě zůstane fronta a UI už má řádek v Driftu.
    unawaited(
      Future<void>(() async {
        try {
          await ref.read(mutationQueueServiceProvider).processQueue();
        } catch (e, st) {
          AppLogger.error('submitWorkerAbsenceRequest: processQueue po enqueue selhalo', e, st);
        }
      }),
    );

    return (WorkerAbsenceSubmitOutcome.successOnline, null);
  } catch (e) {
    return (WorkerAbsenceSubmitOutcome.failure, e.toString());
  }
}
