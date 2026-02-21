import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/services/supabase_service.dart';

/// Placeholder úvodní obrazovka po smazání demo počítadla.
/// Zobrazuje název aplikace z lokalizace - ukázka správného použití i18n.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('app.title'.tr()),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SupabaseService.client.auth.signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          'app.title'.tr(),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
