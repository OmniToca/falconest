import 'package:falconest/core/services/supabase_service.dart';

/// Data záznamu z tabulky invitations – pro zobrazení na obrazovce /invite a pro acceptInvitation.
class InvitationData {
  const InvitationData({
    required this.id,
    required this.profileId,
    required this.email,
    required this.tenantId,
    this.firstName,
    this.lastName,
    this.role = 'admin',
    this.roles = const [],
  });

  final String id;
  final String profileId;
  final String email;
  final String tenantId;
  final String? firstName;
  final String? lastName;
  final String role;
  final List<String> roles;
}

/// Repozitář pro načtení a přijetí pozvánky (tabulka invitations, propojení s profiles a Auth).
class InviteRepository {
  InviteRepository._();
  static final InviteRepository instance = InviteRepository._();

  /// Načte pozvánku podle tokenu z URL. Kanonicky je token **`invitations.id`** (admin i Personál).
  /// Zůstává párování i podle **`profile_id`** kvůli starším odkazům v terénu.
  ///
  /// PROČ RPC místo `.from('invitations').select()`: RLS na `invitations` nepovoluje SELECT
  /// pro roli **anon** ani pro uživatele mimo tenant pozvánky – přímý dotaz vrací 0 řádků.
  /// Funkce **`get_invitation_for_accept`** (SECURITY DEFINER) vrátí nejvýše jeden řádek
  /// jen při známém UUID; bez tokenu nelze tabulku vypsat.
  Future<InvitationData?> fetchInvitationByToken(String token) async {
    if (token.trim().isEmpty) return null;

    final dynamic raw = await SupabaseService.client.rpc(
      'get_invitation_for_accept',
      params: <String, dynamic>{'p_token': token.trim()},
    );

    if (raw == null) return null;
    final map = Map<String, dynamic>.from(raw as Map);

    final id = map['id']?.toString();
    final profileId = map['profile_id']?.toString();
    final email = (map['email']?.toString() ?? '').trim();
    final tenantId = (map['tenant_id']?.toString() ?? '').trim();

    if (id == null || id.isEmpty || profileId == null || profileId.isEmpty ||
        email.isEmpty || tenantId.isEmpty) {
      return null;
    }

    final role = (map['role']?.toString() ?? 'admin').trim();
    List<String> rolesList = [];
    final rolesRaw = map['roles'];
    if (rolesRaw != null && rolesRaw is List) {
      for (final r in rolesRaw) {
        final s = (r?.toString() ?? '').trim();
        if (s.isNotEmpty && ['admin', 'cleaner', 'driver', 'maintenance'].contains(s)) {
          rolesList.add(s);
        }
      }
    }
    if (rolesList.isEmpty) rolesList = [role];

    return InvitationData(
      id: id,
      profileId: profileId,
      email: email,
      tenantId: tenantId,
      firstName: (map['first_name']?.toString() ?? '').trim().isEmpty ? null : map['first_name']?.toString(),
      lastName: (map['last_name']?.toString() ?? '').trim().isEmpty ? null : map['last_name']?.toString(),
      role: role,
      roles: rolesList,
    );
  }

  /// Přijetí pozvánky: registrace uživatele, propojení ghost profilu s auth_id, smazání pozvánky.
  /// Kroky jsou popsány v komentářích. Při chybě vyhazuje výjimku.
  Future<void> acceptInvitation(String token, String password) async {
    final inv = await fetchInvitationByToken(token);
    if (inv == null) {
      throw InviteException('invite.error_invalid_or_expired');
    }

    final email = inv.email;
    if (password.length < 6) {
      throw InviteException('invite.error_password_too_short');
    }

    // 1. Registrace v Supabase Auth – vytvoření účtu s e-mailem z pozvánky a zadaným heslem.
    final response = await SupabaseService.client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw InviteException('invite.error_signup_failed');
    }

    // 2. Přenos dat z pozvánky do profilu: propojení ghost profilu (profile_id) s novým auth_id
    //    a nastavení status = 'active'. Trigger handle_new_user mohl vytvořit druhý řádek v profiles –
    //    ten odstraníme, aby RLS a načítání profilu fungovalo (jeden řádek na auth_id).
    final profileUpdate = <String, dynamic>{
      'auth_id': user.id,
      'status': 'active',
    };
    await SupabaseService.safeFrom('profiles', inv.tenantId)
        .update(profileUpdate)
        .eq('id', inv.profileId);

    // Odstranění případného duplicitního profilu vytvořeného triggerem (stejný auth_id, jiné id).
    try {
      await SupabaseService.safeFrom('profiles', inv.tenantId)
          .delete()
          .eq('auth_id', user.id)
          .neq('id', inv.profileId);
    } catch (_) {
      // RLS nemusí povolit mazání – ignorujeme, hlavní je propojený ghost profil
    }

    // 3. Smaž záznam z tabulky invitations, aby šel token použít jen jednou.
    await SupabaseService.safeFrom('invitations', inv.tenantId).delete().eq('id', inv.id);

    // 4. Přesměrování na dashboard zajistí UI po reloadu profilu (AuthNotifier.reloadProfile).
  }
}

class InviteException implements Exception {
  InviteException(this.i18nKey);
  final String i18nKey;
}
