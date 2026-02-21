import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/invite_repository.dart';

/// Provider načítající pozvánku podle tokenu z URL. Token předává obrazovka /invite.
/// Vrací [AsyncValue]: loading, data(InvitationData), nebo error (null = neplatný token).
final inviteDataProvider = FutureProvider.family<InvitationData?, String>((ref, token) async {
  if (token.trim().isEmpty) return null;
  return InviteRepository.instance.fetchInvitationByToken(token);
});
