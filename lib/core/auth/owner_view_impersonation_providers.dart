import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/features/admin/admin_layout.dart';
import 'package:falconest/features/admin/providers/admin_cross_nav_provider.dart';

/// Efektivní profiles.id pro Owner portál – při náhledu dispečerem profil majitele, jinak přihlášený uživatel.
///
/// PROČ: Owner providery filtrují apartmány přes `apartment_owners.owner_id`; admin JWT zůstává,
/// ale dotazy musí používat profil majitele, ne dispečera.
final effectiveProfileIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return auth.effectiveProfileId;
});

/// True = dispečer prohlíží Owner portál v read-only režimu (Varianta C MVP).
final isOwnerViewReadOnlyProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).state.isOwnerViewImpersonating;
});

/// Kontext aktivního owner view – jméno majitele a clientId pro banner a návrat do CRM.
typedef OwnerViewImpersonationInfo = ({
  String? displayName,
  String? clientId,
});

/// Informace pro banner a navigaci zpět do detailu klienta.
final ownerViewImpersonationInfoProvider = Provider<OwnerViewImpersonationInfo>((ref) {
  final state = ref.watch(authNotifierProvider).state;
  return (
    displayName: state.impersonatedOwnerDisplayName,
    clientId: state.impersonatedOwnerClientId,
  );
});

/// Skutečný profil dispečera – pro audit, FCM a mutace, které nesmí jít jménem majitele.
final realProfileIdProvider = Provider<String?>((ref) {
  return ref.watch(authNotifierProvider).realProfileId;
});

/// Ukončí náhled Owner portálu a vrátí dispečera do Admin CRM na detail stejného klienta.
///
/// PROČ: Admin navigace je IndexedStack – stačí přepnout záložku Klienti a přes
/// [adminCrossNavPendingProvider] znovu otevřít [ClientDetailDialog] (stejný vzor jako křížová navigace).
Future<void> returnFromOwnerView(BuildContext context, WidgetRef ref) async {
  final clientId = ref.read(authNotifierProvider).state.impersonatedOwnerClientId;

  await ref.read(authNotifierProvider).stopOwnerView();

  ref.read(adminTabJumpRequestProvider.notifier).state = adminTabIndexClients;

  final cid = clientId?.trim();
  if (cid != null && cid.isNotEmpty) {
    ref.read(adminCrossNavPendingProvider.notifier).openClient(cid);
  }

  if (context.mounted) {
    context.go('/admin');
  }
}
