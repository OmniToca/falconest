import 'package:falconest/core/services/supabase_service.dart';

/// Jeden záznam z tabulky [owner_portal_view_sessions] – audit náhledu Owner portálu dispečerem.
///
/// PROČ: Dispečer (admin/manager) může z CRM prohlížet Klientský portál majitele
/// bez odhlášení. Každé spuštění a ukončení musí být dohledatelné pro audit podpory.
class OwnerPortalViewSessionRow {
  const OwnerPortalViewSessionRow({
    required this.id,
    required this.adminProfileId,
    required this.viewedOwnerProfileId,
    required this.clientId,
    required this.tenantId,
    required this.startedAt,
    this.endedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String adminProfileId;
  final String viewedOwnerProfileId;
  final String clientId;
  final String tenantId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Zda session ještě probíhá (ended_at je null).
  bool get isActive => endedAt == null;
}

/// Repozitář pro tabulku [owner_portal_view_sessions].
///
/// PROČ: AuthNotifier při startOwnerView vytvoří záznam a při stopOwnerView ho uzavře.
/// Po F5 client state zmizí – [closeMyOpenSessions] ukončí orphan řádky, aby
/// RESTRICTIVE RLS (`has_active_owner_portal_view_session`) nezablokovalo admin mutace.
class OwnerPortalViewSessionsRepository {
  OwnerPortalViewSessionsRepository();

  /// Ukončí všechny otevřené session volajícího admina (RPC close_my_open_…).
  ///
  /// PROČ: Orphan po F5 / pádu tabu by jinak 8 h blokoval INSERT/UPDATE tasks přes RLS.
  Future<void> closeMyOpenSessions() async {
    await SupabaseService.client.rpc('close_my_open_owner_portal_view_sessions');
  }

  /// Vytvoří novou audit session (začátek náhledu Owner portálu).
  ///
  /// Vrací ID záznamu pro uložení v [AuthNotifier] a pozdější [endSession].
  Future<String> startSession({
    required String adminProfileId,
    required String viewedOwnerProfileId,
    required String clientId,
    required String tenantId,
  }) async {
    if (adminProfileId.isEmpty ||
        viewedOwnerProfileId.isEmpty ||
        clientId.isEmpty ||
        tenantId.isEmpty) {
      throw ArgumentError(
        'adminProfileId, viewedOwnerProfileId, clientId a tenantId musí být neprázdné',
      );
    }

    // Před novým náhledem uzavřít orphan session stejného dispečera.
    try {
      await closeMyOpenSessions();
    } catch (_) {
      // Nekritické – INSERT nové session může i tak projít; assert/RLS má TTL 8 h.
    }

    final res = await SupabaseService.client
        .from('owner_portal_view_sessions')
        .insert({
          'admin_profile_id': adminProfileId,
          'viewed_owner_profile_id': viewedOwnerProfileId,
          'client_id': clientId,
          'tenant_id': tenantId,
        })
        .select('id')
        .single();

    final id = res['id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('INSERT owner_portal_view_sessions nevrátil id');
    }
    return id;
  }

  /// Ukončí session: nastaví [ended_at] a [updated_at].
  ///
  /// Volá se z AuthNotifier při ukončení režimu „Prohlížíte jako …“.
  Future<void> endSession(String sessionId) async {
    if (sessionId.isEmpty) {
      throw ArgumentError('sessionId musí být neprázdný');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await SupabaseService.client.from('owner_portal_view_sessions').update({
      'ended_at': now,
      'updated_at': now,
    }).eq('id', sessionId).select();
  }
}
