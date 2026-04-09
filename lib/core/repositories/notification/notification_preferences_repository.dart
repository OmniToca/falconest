import 'package:falconest/core/models/notification_preferences_model.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Čtení a zápis řádku v [notification_preferences] pro aktuální profil tenanta.
///
/// PROČ: Jedno místo pro upsert – při první změně přepínače vytvoří řádek, jinak UPDATE přes `profile_id`.
class NotificationPreferencesRepository {
  NotificationPreferencesRepository._();

  static final NotificationPreferencesRepository instance =
      NotificationPreferencesRepository._();

  /// Načte preference nebo vrátí null, pokud v DB řádek ještě není (UI použije výchozí true).
  Future<NotificationPreferencesModel?> fetchByProfile({
    required String profileId,
    required String tenantId,
  }) async {
    if (profileId.isEmpty || tenantId.isEmpty) return null;
    final res = await SupabaseService.safeFrom('notification_preferences', tenantId)
        .select()
        .eq('profile_id', profileId)
        .maybeSingle();
    if (res == null) return null;
    return NotificationPreferencesModel.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  /// Upsert podle `profile_id` – sloupec `tenant_id` vnutí [safeInsertPayload].
  Future<void> upsert(NotificationPreferencesModel model) async {
    final payload = SupabaseService.safeInsertPayload(model.tenantId, model.toMap());
    await SupabaseService.client.from('notification_preferences').upsert(
          payload,
          onConflict: 'profile_id',
        );
  }
}
