import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Obrazovka zobrazená při načítání profilu po přihlášení.
///
/// Zobrazuje se, když Supabase potvrdí přihlášení, ale aplikace ještě
/// nestihla načíst role a tenant_id z tabulky profiles. Router sem přesměruje
/// uživatele, aby nedocházelo k race condition a nesprávnému přesměrování.
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'common.loading'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
