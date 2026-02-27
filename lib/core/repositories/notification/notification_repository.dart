import 'package:falconest/core/models/notification_model.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/supabase_stream_helper.dart';

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

  /// Označí všechny nepřečtené notifikace daného profilu jako přečtené.
  ///
  /// PROČ: Jedním kliknutím "Přečíst vše" v dropdownu notifikací.
  /// RLS ověří tenant_id a profile_id z JWT.
  Future<void> markAllAsRead(String profileId) async {
    if (profileId.isEmpty) return;
    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('profile_id', profileId)
        .eq('is_read', false);
  }

  /// Stream nepřečtených notifikací pro daný profil v reálném čase.
  ///
  /// PROČ: Dispečer musí vidět problém z terénu okamžitě bez nutnosti refreshovat stránku.
  /// Supabase Realtime Stream se o to stará na pozadí – při INSERT nové notifikace nebo
  /// UPDATE (is_read) se stream automaticky aktualizuje.
  ///
  /// PROČ resilientSupabaseStream: Chyby WebSocketu (Code 1000) se nikdy nepropagují do Riverpodu.
  ///
  /// POZNÁMKA: Tabulka notifications musí být v Supabase Replication (Dashboard → Database → Replication),
  /// jinak stream nebude přijímat změny.
  ///
  /// OMEZENÍ: Supabase stream podporuje pouze jeden filtr – používáme inFilter(profile_id).
  /// Filtrování is_read probíhá na straně klienta v .map().
  /// PROČ: Bezpečnostní limit 50 záznamů, aby nedošlo k zahlcení paměti u velkých agentur.
  ///
  /// [profileId] – profiles.id aktuálně přihlášeného uživatele (RLS filtruje i podle tenant_id z JWT).
  Stream<List<NotificationModel>> watchUnreadNotifications(String profileId) {
    if (profileId.isEmpty) return Stream.value([]);
    return resilientSupabaseStream<List<NotificationModel>>(
      streamBuilder: () => SupabaseService.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .inFilter('profile_id', [profileId])
          .order('created_at', ascending: false)
          .limit(50)
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
          }),
      debugLabel: 'NotificationRepository.watchUnreadNotifications',
    );
  }
}
