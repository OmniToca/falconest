import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/owner_view_impersonation_providers.dart';

/// Vrátí true, pokud dispečer prohlíží portál v read-only režimu – pro guard u otevírání dialogů.
bool isOwnerPortalReadOnly(WidgetRef ref) => ref.read(isOwnerViewReadOnlyProvider);

/// Skryje mutační UI (FAB, tlačítka, formuláře) během read-only náhledu Owner portálu dispečerem.
///
/// PROČ: Varianta C MVP – admin JWT má širší RLS; mutace z owner obrazovek jsou zakázány,
/// dokud dispečer neukončí režim „Prohlížíte jako …“. [fallback] nahradí [child] v read-only režimu.
class OwnerReadOnlyGate extends ConsumerWidget {
  const OwnerReadOnlyGate({
    super.key,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readOnly = ref.watch(isOwnerViewReadOnlyProvider);
    return readOnly ? fallback : child;
  }
}
