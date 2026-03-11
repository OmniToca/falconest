import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Model profilu aktuálně přihlášeného uživatele – jméno a e-mail.
///
/// Slouží pro vizitku v Nastavení. Jméno se bere z profiles (first_name + last_name nebo name),
/// e-mail z auth.users nebo profiles.
class CurrentUserProfile {
  const CurrentUserProfile({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;
}

/// Načte profil aktuálního uživatele z tabulky [profiles].
///
/// Používá auth_id z auth.state.user.id. Vrací jméno (first_name + last_name nebo name)
/// a e-mail. Pokud profil není nalezen, e-mail se bere z auth.users.
final currentUserProfileProvider = FutureProvider<CurrentUserProfile>((ref) async {
  final user = ref.watch(authNotifierProvider).state.user;
  if (user == null) return const CurrentUserProfile(name: '', email: '');

  final emailFromAuth = (user.email ?? '').trim();

  try {
    final res = await SupabaseService.client
        .from('profiles')
        .select('name, first_name, last_name, email')
        .eq('auth_id', user.id)
        .isFilter('deleted_at', null)
        .maybeSingle();

    if (res == null) {
      return CurrentUserProfile(name: '', email: emailFromAuth);
    }

    final map = Map<String, dynamic>.from(res as Map);
    final first = (map['first_name']?.toString() ?? '').trim();
    final last = (map['last_name']?.toString() ?? '').trim();
    var name = '$first $last'.trim();
    if (name.isEmpty) {
      name = (map['name']?.toString() ?? '').trim();
    }
    final emailFromProfile = (map['email']?.toString() ?? '').trim();
    final email = emailFromProfile.isNotEmpty ? emailFromProfile : emailFromAuth;

    return CurrentUserProfile(name: name, email: email);
  } catch (_) {
    return CurrentUserProfile(name: '', email: emailFromAuth);
  }
});
