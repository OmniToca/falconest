import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Jednorázový klíč pro easy_localization (např. `errors.offline_web_save_failed`).
///
/// PROČ: AsyncNotifier / repository nemají [BuildContext]; nastavením tohoto stavu
/// [TransientI18nSnackHost] v kořeni aplikace zobrazí [SnackBar] a klíč zase vymaže.
final transientI18nSnackKeyProvider = StateProvider<String?>((ref) => null);
