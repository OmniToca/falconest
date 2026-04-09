import 'package:falconest/core/models/notification_model.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/supabase_stream_helper.dart';

/// Repozitář pro notifikace – čtení a označování jako přečtené.
///
/// Slouží pro zvoneček v Top Baru. Všechny operace jdou přímo do Supabase.
/// RLS zajišťuje, že uživatel vidí jen notifikace pro svůj profil a agenturu.
/// Frontend Firewall: při neprázdném [tenantId] používáme [safeFrom], aby Super Admin
/// neviděl notifikace mimo zvolený tenant (u streamu se kromě tenantu filtruje i [profileId] v mapě).
class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  /// Označí notifikaci jako přečtenou.
  ///
  /// [tenantId] – `tenantIdForData`; při null zůstává chování jako holý klient (globální kontext).
  Future<void> markAsRead(String notificationId, String? tenantId) async {
    if (notificationId.isEmpty) return;
    // Bezpečnostní vynucení tenant_id klauzule přes safeFrom (null = záměrně nescoped, např. super admin).
    await SupabaseService.safeFrom('notifications', tenantId)
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Označí všechny nepřečtené notifikace daného profilu jako přečtené.
  ///
  /// PROČ: Jedním kliknutím "Přečíst vše" v dropdownu notifikací.
  Future<void> markAllAsRead(String profileId, String? tenantId) async {
    if (profileId.isEmpty) return;
    await SupabaseService.safeFrom('notifications', tenantId)
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
  /// OMEZENÍ: Stream API má jen jeden inFilter. S [safeFrom] filtrujeme tenant; profil a is_read
  /// dořešíme v [.map] na klientovi (stejný vzor jako u rezervací v admin streamu).
  /// PROČ: Bezpečnostní limit 50 záznamů, aby nedošlo k zahlcení paměti u velkých agentur.
  ///
  /// [profileId] – profiles.id aktuálně přihlášeného uživatele.
  Stream<List<NotificationModel>> watchUnreadNotifications(
    String profileId,
    String? tenantId,
  ) {
    if (profileId.isEmpty) return Stream.value([]);

    if (tenantId != null && tenantId.isNotEmpty) {
      return resilientSupabaseStream<List<NotificationModel>>(
        streamBuilder: () => SupabaseService.safeFrom('notifications', tenantId)
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .limit(50)
            .map((List<Map<String, dynamic>> rows) {
              final models = rows
                  .where((r) =>
                      (r['profile_id']?.toString() ?? '') == profileId &&
                      r['is_read'] != true)
                  .map((r) => NotificationModel.fromJson(Map<String, dynamic>.from(r)))
                  .toList();
              models.sort((a, b) {
                final ta = a.createdAt ?? DateTime(0);
                final tb = b.createdAt ?? DateTime(0);
                return tb.compareTo(ta);
              });
              return models;
            }),
        debugLabel: 'NotificationRepository.watchUnreadNotifications.scoped',
      );
    }

    // Výjimka z holého safeFrom: [SupabaseStreamBuilder] po .stream() nepodporuje stejný řetězec jako
    // PostgREST builder; scoped tenant zde chybí záměrně – data zužujeme .inFilter(profile_id) + RLS.
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
