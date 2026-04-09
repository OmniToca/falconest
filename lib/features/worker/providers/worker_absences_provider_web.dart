import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';

/// Web: Drift na klientovi není – absence se načítají přímo ze Supabase (RLS + tenant).
final workerAbsencesProvider = FutureProvider<List<StaffAbsence>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final profileId = auth.state.profileId;
  final tenantId = auth.tenantIdForData;
  if (profileId == null || profileId.isEmpty || tenantId == null || tenantId.isEmpty) {
    return [];
  }
  try {
    final res = await SupabaseService.safeFrom('staff_absences', tenantId)
        .select('id, profile_id, invitation_id, start_date, end_date, reason, status')
        .eq('profile_id', profileId)
        .order('start_date', ascending: false);
    final list = res as List;
    return list
        .map((e) => StaffAbsence.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (e, st) {
    AppLogger.error('workerAbsencesProvider (web): načtení absencí selhalo', e, st);
    return [];
  }
});
