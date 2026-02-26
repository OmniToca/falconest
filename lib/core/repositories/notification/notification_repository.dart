import 'package:falconest/core/models/notification_model.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Repozitář pro notifikace – čtení a označování jako přečtené.
///
/// Slouží pro zvoneček v Top Baru. Všechny operace jdou přímo do Supabase.
/// RLS zajišťuje, že uživatel vidí jen notifikace pro svůj profil a agenturu.
class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  /// Označí notifikaci jako přečtenou.
  ///
  /// RLS ověří, že uživatel smí upravit jen řádky s profile_id == jeho profil a tenant_id == jeho agentura.
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Stream nepřečtených notifikací pro daný profil v reálném čase.
  ///
  /// PROČ: Dispečer musí vidět problém z terénu okamžitě bez nutnosti refreshovat stránku.
  /// Supabase Realtime Stream se o to stará na pozadí – při INSERT nové notifikace nebo
  /// UPDATE (is_read) se stream automaticky aktualizuje.
  ///
  /// POZNÁMKA: Tabulka notifications musí být v Supabase Replication (Dashboard → Database → Replication),
  /// jinak stream nebude přijímat změny.
  ///
  /// OMEZENÍ: Supabase stream podporuje pouze jeden filtr – používáme inFilter(profile_id).
  /// Filtrování is_read a řazení probíhá na straně klienta v .map().
  ///
  /// [profileId] – profiles.id aktuálně přihlášeného uživatele (RLS filtruje i podle tenant_id z JWT).
  Stream<List<NotificationModel>> watchUnreadNotifications(String profileId) {
    if (profileId.isEmpty) {
      return Stream.value([]);
    }

    return SupabaseService.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .inFilter('profile_id', [profileId])
        .map((List<Map<String, dynamic>> rows) {
          final models = rows
              .map((r) => NotificationModel.fromJson(Map<String, dynamic>.from(r)))
              .where((n) => !n.isRead)
              .toList();
          models.sort((a, b) {
            final ta = a.createdAt ?? DateTime(0);
            final tb = b.createdAt ?? DateTime(0);
            return tb.compareTo(ta);
          });
          return models;
        });
  }
}
