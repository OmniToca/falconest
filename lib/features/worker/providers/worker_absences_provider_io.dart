import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';

/// Vlastní absence workera z Driftu – reaktivní stream po syncu i po lokálním přidání.
///
/// PROČ: Obrazovka nesmí volat Supabase; data dorazí z [WorkerSyncService] a nové řádky
/// se zapisují přes [DriftStaffAbsenceRepository.insertPendingAbsence] před mutací.
final workerAbsencesProvider = StreamProvider.autoDispose<List<StaffAbsence>>((ref) {
  final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
  final profileId = ref.watch(authNotifierProvider).profileId;
  if (tenantId == null || tenantId.isEmpty || profileId == null || profileId.isEmpty) {
    return Stream.value(const <StaffAbsence>[]);
  }
  final repo = ref.watch(driftStaffAbsenceRepositoryProvider);
  return repo.watchForProfile(tenantId, profileId).map((rows) {
    return rows
        .map(
          (r) => StaffAbsence(
            id: r.supabaseId,
            profileId: r.profileId,
            invitationId: r.invitationId,
            startDate: r.startDate,
            endDate: r.endDate,
            reason: r.reason.trim().isEmpty ? null : r.reason,
            status: r.status.trim().isEmpty ? null : r.status,
          ),
        )
        .toList();
  });
});
