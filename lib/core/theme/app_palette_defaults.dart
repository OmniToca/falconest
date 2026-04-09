import 'package:flutter/material.dart';

import 'package:falconest/core/theme/custom_colors.dart';

/// Výchozí paleta FalcoNest – jeden zdroj pravdy pro [AppTheme] i editor barev v Nastavení.
///
/// PROČ: Uživatelské přepsání musí mít stejné „oficiální“ výchozí hodnoty jako původní
/// hardcoded konstanty; duplicita by vedla k nesouladu mezi „Obnovit výchozí“ a prvním spuštěním.
abstract final class AppPaletteDefaults {
  /// Oficiální modrá z loga FalcoNest (zářivý akcent); musí ladit s přihlášením a admin panelem.
  static const Color primary = Color(0xFF1E5FCD);
  static const Color secondary = Color(0xFFF97316);
  static const Color scaffoldBackground = Color(0xFFF8FAFC);
  static const Color cardColor = Color(0xFFFFFFFF);

  /// Pozadí postranního menu v admin části – brandová tmavší modrá; nepoužívat jako globální [ColorScheme.surface].
  static const Color sidebarBackground = Color(0xFF2753A9);

  /// Chyba dle Material 3 odvozená od primární barvy (stejné chování jako dříve u seed).
  static Color get schemeError => ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
  ).error;

  static Color get success => CustomColors.light.success;
  static Color get warning => CustomColors.light.warning;
  static Color get info => CustomColors.light.info;
}
