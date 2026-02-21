import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Firemní barvy FalcoNest – konzistentní s login obrazovkou.
const _primaryBlue = Color(0xFF1565C0);
const _accentOrange = Color(0xFFE65100);

/// Obrazovka „Čekárna“ pro uživatele, kteří nemají přiřazenou agenturu (tenant_id).
///
/// Zobrazuje se po přihlášení, když uživatel má roli != super_admin
/// a tenant_id == null. Administrátor musí uživatele přiřadit k agentuře,
/// poté bude přesměrován do aplikace.
///
/// Když je [profileLoadError] nastaven (chyba načtení profilu), zobrazí se
/// chybová zpráva místo standardního textu – uživatel pak ví, že má problém
/// s profilem, ne že jen čeká na schválení.
class WaitingRoomScreen extends ConsumerWidget {
  const WaitingRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.watch(authNotifierProvider);
    final profileError = authNotifier.profileLoadError;
    return Scaffold(
      backgroundColor: _primaryBlue,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Velká ikona – štít jako symbol bezpečnosti/schvalování
                  Icon(
                    Icons.security,
                    size: 96,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    profileError ?? 'waiting_room.message'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profileError != null
                        ? 'waiting_room.profile_error_hint'.tr()
                        : 'waiting_room.submessage'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  FilledButton(
                    onPressed: () async {
                      await SupabaseService.client.auth.signOut();
                      if (context.mounted) {
                        context.go('/');
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'waiting_room.btn_logout'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
