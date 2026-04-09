import 'package:flutter/material.dart';

import 'package:falconest/core/theme/custom_colors.dart';

/// Zkratky pro čtení tématu z [BuildContext] bez opakování [Theme.of].
///
/// PROČ: Kratší zápis ve widgetech a konzistentní přístup k [CustomColors].
/// [customColors] vyžaduje, aby [CustomColors] bylo zaregistrováno v
/// [ThemeData.extensions] (viz [AppTheme.lightTheme]).
extension BuildContextThemeExt on BuildContext {
  /// Aktuální Material 3 [ColorScheme] (primární, plochy, chyba, …).
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Aktuální [TextTheme] (titulky, body, labely).
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Sémantické barvy success / warning / info z [CustomColors].
  ///
  /// Poznámka: používá `!` – pokud rozšíření v tématu chybí, dojde k výjimce za běhu.
  /// V produkční aplikaci musí být [CustomColors] vždy součástí tématu.
  CustomColors get customColors => Theme.of(this).extension<CustomColors>()!;
}
