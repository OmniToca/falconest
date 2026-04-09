import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/database/drift/database_provider.dart';
import 'package:falconest/core/database/drift/repositories/drift_user_profile_repository.dart';
import 'package:falconest/core/models/current_user_profile.dart';

/// Mobil: profil z Drift cache; obnovuje se při worker synci (Supabase z UI nevoláme).
///
/// PROČ: Stream překreslí drawer ihned po synci; offline zůstane poslední známá vizitka + e-mail z Auth.
final currentUserProfileProvider = StreamProvider<CurrentUserProfile>((ref) {
  final user = ref.watch(authNotifierProvider).state.user;
  if (user == null) {
    return Stream.value(const CurrentUserProfile(name: '', email: ''));
  }
  final emailFromAuth = (user.email ?? '').trim();
  final uid = user.id.trim();
  if (uid.isEmpty) {
    return Stream.value(CurrentUserProfile(name: '', email: emailFromAuth));
  }
  final repo = ref.watch(driftUserProfileRepositoryProvider);
  return repo.watchByAuthUserId(uid).map(
        (row) => DriftUserProfileRepository.toCurrentUserProfile(row, emailFromAuth),
      );
});
