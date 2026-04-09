import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/offline/transient_i18n_snack_provider.dart';

/// Poslouchá [transientI18nSnackKeyProvider] a zobrazí lokalizovaný SnackBar.
///
/// PROČ: Offline zápis na webu končí [OfflineWebException] v Notifieru bez kontextu;
/// tento host obalí [MaterialApp] a poskytne jednotnou zpětnou vazbu bez duplicity kódu v každém screenu.
class TransientI18nSnackHost extends ConsumerWidget {
  const TransientI18nSnackHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PROČ: listen v build je v Riverpodu správný vzor – předchozí subscription se uvolní při rebuildu.
    ref.listen<String?>(transientI18nSnackKeyProvider, (previous, next) {
      if (next == null || next.isEmpty) return;
      // PROČ: Po frame má ScaffoldMessenger z routeru jistotu, že je pod stromem MaterialApp.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.tr())),
        );
        ref.read(transientI18nSnackKeyProvider.notifier).state = null;
      });
    });
    return child;
  }
}
