import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';

/// Provider načítající pouze nepřítomnosti přihlášeného uživatele (Worker flow).
///
/// Filtruje podle profile_id == currentUser.profileId a tenant_id.
/// Pro mobilní pracovníky – zobrazení vlastních dovolených a nemocí.
final workerAbsencesProvider = FutureProvider<List<StaffAbsence>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final profileId = auth.state.profileId;
  final tenantId = auth.tenantIdForData;
  if (profileId == null || profileId.isEmpty || tenantId == null || tenantId.isEmpty) {
    return [];
  }
  try {
    final res = await SupabaseService.client
        .from('staff_absences')
        .select('id, profile_id, invitation_id, start_date, end_date, reason, status')
        .eq('profile_id', profileId)
        .eq('tenant_id', tenantId)
        .order('start_date', ascending: false);
    final list = res as List;
    return list
        .map((e) => StaffAbsence.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (_) {
    return [];
  }
});

/// Pomocná funkce pro formátování data v UI.
String formatAbsenceDate(DateTime d) {
  return DateFormat('dd.MM.yyyy').format(d);
}
