import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/notification_preferences_model.dart';
import 'package:falconest/core/repositories/notification/notification_preferences_repository.dart';

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>(
  (ref) => NotificationPreferencesRepository.instance,
);

/// Preference oznámení z tabulky [notification_preferences] (matice kanálů web / push / e-mail).
///
/// Po změně checkboxu okamžitě uložíme upsertem; při chybě zůstane předchozí stav v UI.
final notificationPreferencesProvider =
    AsyncNotifierProvider<NotificationPreferencesNotifier, NotificationPreferencesModel?>(
  NotificationPreferencesNotifier.new,
);

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferencesModel?> {
  NotificationPreferencesRepository get _repo =>
      ref.read(notificationPreferencesRepositoryProvider);

  @override
  Future<NotificationPreferencesModel?> build() async {
    final auth = ref.watch(authNotifierProvider);
    final pid = auth.state.profileId;
    final tid = auth.state.tenantId;
    if (pid == null || pid.isEmpty || tid == null || tid.isEmpty) {
      return null;
    }
    final row = await _repo.fetchByProfile(profileId: pid, tenantId: tid);
    return row ??
        NotificationPreferencesModel(
          profileId: pid,
          tenantId: tid,
        );
  }

  /// Uloží celý model (po změně jednoho přepínače). Při chybě vrátí UI předchozí hodnoty; [false] = selhání.
  Future<bool> save(NotificationPreferencesModel next) async {
    final previous = state.valueOrNull;
    state = await AsyncValue.guard(() async {
      await _repo.upsert(next);
      return next;
    });
    if (state.hasError) {
      if (previous != null) {
        state = AsyncData(previous);
      }
      return false;
    }
    return true;
  }
}
