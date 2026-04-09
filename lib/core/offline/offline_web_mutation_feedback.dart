import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/offline/transient_i18n_snack_provider.dart';

/// Nahlásí uživateli, že na webu nelze bez sítě ukládat do mutační fronty.
///
/// PROČ: Voláno z catch větví po [OfflineWebException]; stejný text jako u manuálního SnackBaru.
void reportOfflineWebMutationEnqueueFailed(Ref ref) {
  ref.read(transientI18nSnackKeyProvider.notifier).state =
      'errors.offline_web_save_failed';
}
