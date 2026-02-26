import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/notification_model.dart';
import 'package:falconest/core/repositories/notification/notification_repository.dart';

/// Provider pro [NotificationRepository] – singleton instance.
///
/// Repozitář slouží pro markAsRead a jako zdroj pro watchUnreadNotifications.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository.instance;
});

/// Stream provider pro nepřečtené notifikace aktuálního uživatele.
///
/// PROČ: Dispečer musí vidět problém z terénu okamžitě bez nutnosti refreshovat stránku.
/// Supabase Stream se o to stará na pozadí – při INSERT nové notifikace se stream automaticky aktualizuje.
///
/// Závisí na [authNotifierProvider] – při odhlášení (profileId == null) vrací prázdný seznam.
/// Multi-tenant: RLS na backendu filtruje podle tenant_id z JWT, takže uživatel vidí jen notifikace své agentury.
final unreadNotificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final profileId = ref.watch(authNotifierProvider).state.profileId;
  if (profileId == null || profileId.isEmpty) {
    return Stream.value([]);
  }

  return ref.read(notificationRepositoryProvider).watchUnreadNotifications(profileId);
});
