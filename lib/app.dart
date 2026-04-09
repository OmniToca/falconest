import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/app/app_lifecycle_fcm_listener.dart';
import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/push_notification_service.dart';
import 'package:falconest/core/offline/mutation_queue_service.dart';
import 'package:falconest/core/offline/network_sync_watcher.dart';
import 'package:falconest/core/offline/transient_i18n_snack_host.dart';
import 'package:falconest/core/presentation/root_scaffold_messenger.dart';
import 'package:falconest/core/router/app_router.dart';
import 'package:falconest/features/settings/providers/tenant_colors_provider.dart';

/// Hlavní aplikační widget FalcoNest.
///
/// Používá [goRouterProvider] – router reaguje na změny auth stavu
/// (refreshListenable). Přesměrování po přihlášení řeší globální redirect.
/// [NetworkSyncWatcher] na pozadí poslouchá connectivity a při návratu sítě
/// automaticky odešle pending změny (úkoly, rezervace, audit).
/// Téma bere [appThemeFromTenantColorsProvider] (Drift + Supabase `tenant_ui_preferences`).
/// Veškeré texty musí být lokalizovány přes easy_localization.
class FalcoNestApp extends ConsumerWidget {
  const FalcoNestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final theme = ref.watch(appThemeFromTenantColorsProvider);
    // PROČ: Předběžný read mutationQueueServiceProvider – zajistí MutationQueueService.instance
    // pro CashWalletRepository a další singletons, které nemají Ref.
    ref.watch(mutationQueueServiceProvider);

    return NetworkSyncWatcher(
      child: AppLifecycleFcmListener(
        child: _PushRouterBinder(
          child: TransientI18nSnackHost(
            child: MaterialApp.router(
              scaffoldMessengerKey: rootScaffoldMessengerKey,
              title: 'app.title'.tr(),
              theme: theme,
              themeMode: ThemeMode.light,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routerConfig: router,
            ),
          ),
        ),
      ),
    );
  }
}

/// Naváže [GoRouter] na FCM deep link (`data.route` z [PushNotificationService]).
class _PushRouterBinder extends ConsumerStatefulWidget {
  const _PushRouterBinder({required this.child});

  final Widget child;

  @override
  ConsumerState<_PushRouterBinder> createState() => _PushRouterBinderState();
}

class _PushRouterBinderState extends ConsumerState<_PushRouterBinder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final r = ref.read(goRouterProvider);
      PushNotificationService.instance.attachGoRouter(r);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(goRouterProvider, (previous, next) {
      PushNotificationService.instance.attachGoRouter(next);
    });
    // Po odhlášení [PushNotificationService.dispose] zruší posluchače – po novém přihlášení
    // znovu navážeme router (stejná instance [GoRouter] nebo nová po refreshi provideru).
    ref.listen(authNotifierProvider, (previous, next) {
      final router = ref.read(goRouterProvider);
      PushNotificationService.instance.attachGoRouter(router);
    });
    return widget.child;
  }
}
