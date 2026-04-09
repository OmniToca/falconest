import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/current_user_profile.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Web: profil z tabulky `profiles` přes Supabase (Drift na klientovi není).
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
  } catch (e, st) {
    AppLogger.error('currentUserProfileProvider (web): načtení profilu selhalo', e, st);
    return CurrentUserProfile(name: '', email: emailFromAuth);
  }
});
