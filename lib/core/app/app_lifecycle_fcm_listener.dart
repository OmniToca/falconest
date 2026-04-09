import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';

/// Po startu UI a při návratu z pozadí znovu spustí registraci FCM do `user_devices`.
///
/// PROČ: Na iOS může APNS token dorazit až sekundy po prvním pokusu; uživatel už je přihlášený
/// a [AuthNotifier._loadRoleAndNotify] už doběhl dřív. Opakované [retryFcmRegistrationIfLoggedIn]
/// je levné a zvýší šanci, že [FirebaseMessaging.getToken] uspěje a zápis do DB proběhne.
class AppLifecycleFcmListener extends ConsumerStatefulWidget {
  const AppLifecycleFcmListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleFcmListener> createState() =>
      _AppLifecycleFcmListenerState();
}

class _AppLifecycleFcmListenerState extends ConsumerState<AppLifecycleFcmListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).retryFcmRegistrationIfLoggedIn();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authNotifierProvider.notifier).retryFcmRegistrationIfLoggedIn();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
