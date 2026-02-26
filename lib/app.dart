import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/offline/network_sync_watcher.dart';
import 'package:falconest/core/router/app_router.dart';
import 'package:falconest/core/theme/app_theme.dart';

/// Hlavní aplikační widget FalcoNest.
///
/// Používá [goRouterProvider] – router reaguje na změny auth stavu
/// (refreshListenable). Přesměrování po přihlášení řeší globální redirect.
/// [NetworkSyncWatcher] na pozadí poslouchá connectivity a při návratu sítě
/// automaticky odešle pending změny (úkoly, rezervace, audit).
/// Veškeré texty musí být lokalizovány přes easy_localization.
class FalcoNestApp extends ConsumerWidget {
  const FalcoNestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return NetworkSyncWatcher(
      child: MaterialApp.router(
        title: 'app.title'.tr(),
        theme: AppTheme.lightTheme,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        routerConfig: router,
      ),
    );
  }
}
