import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Zamykací obrazovka pro neplatiče – tenant má paid_until v minulosti.
///
/// Minimalistický design bez navigace (App bar, menu) – jediná cesta ven je Odhlásit.
/// SECURITY: Žádné navigační prvky, aby aplikaci nešlo obejít.
class PaymentRequiredScreen extends ConsumerWidget {
  const PaymentRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 120,
                color: Colors.white.withValues(alpha: 0.95),
              ),
              const SizedBox(height: 32),
              Text(
                'payment_required.title'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'payment_required.subtitle'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.4,
                    ),
              ),
              const Spacer(),
              // Zkusit znovu – pokud Super Admin mezitím prodloužil paid_until, refresh pustí uživatele dál.
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await ref.read(authNotifierProvider).refreshTenantPaymentStatus();
                    if (context.mounted) {
                      // Router redirect se spustí po notifyListeners a případně přesměruje na dashboard.
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.9),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('payment_required.try_again'.tr()),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await SupabaseService.client.auth.signOut();
                    if (context.mounted) context.go('/');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('admin.menu_logout'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
