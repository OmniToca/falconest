import 'package:flutter/material.dart';

import 'package:falconest/core/theme/app_palette_defaults.dart';
import 'package:falconest/core/theme/custom_colors.dart';

/// Rozšíření tématu – vlastní barvy (cardColor) pro AppCard a další widgety.
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({required this.cardColor});

  final Color cardColor;

  @override
  AppThemeColors copyWith({Color? cardColor}) =>
      AppThemeColors(cardColor: cardColor ?? this.cardColor);

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
    );
  }
}

/// Centrální téma aplikace – světlý režim s prémiovou paletou a volitelnými brand barvami tenanta.
class AppTheme {
  AppTheme._();

  /// Zachováno pro kód, který očekává statické světlé téma bez přepsání.
  static ThemeData get lightTheme => buildLightThemeForTenant();

  /// Produktové téma: dynamicky jen **primární a sekundární** brand barva tenanta; sémantika z [CustomColors.light].
  ///
  /// PROČ B2B konzistence: chyba / úspěch / varování / info zůstávají staticky v `custom_colors.dart`, aby je uživatel
  /// nemohl „rozbít“ color pickerem. [ColorScheme.error] držíme z [AppPaletteDefaults.schemeError] (odvozeno od
  /// výchozího brand primary), nikoli od uživatelsky zvolené primární barvy – stabilní význam „chyby“ v UI.
  ///
  /// Vynucen světlý vzhled (Light Mode): [ColorScheme.fromSeed] barví i `surface*` odstíny podle primární barvy
  /// (Material 3) – karty a formuláře by pak působily modře. Proto přepisujeme všechny surface kontejnery na neutrální
  /// bílou / šedou; brandová modrá zůstává jen u `primary` / tlačítek. Pozadí sidebaru je výjimka v paletě
  /// ([AppPaletteDefaults.sidebarBackground]), ne v tomto schématu.
  static ThemeData buildLightThemeForTenant({
    Color? brandPrimary,
    Color? brandSecondary,
  }) {
    final primary = brandPrimary ?? AppPaletteDefaults.primary;
    final secondary = brandSecondary ?? AppPaletteDefaults.secondary;

    var colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );

    const surfaceWhite = Color(0xFFFFFFFF);
    const onSurfaceDark = Color(0xFF1C1B1F);
    const onSurfaceMuted = Color(0xFF49454F);

    colorScheme = colorScheme.copyWith(
      primary: primary,
      secondary: secondary,
      error: AppPaletteDefaults.schemeError,
      brightness: Brightness.light,
      surface: surfaceWhite,
      onSurface: onSurfaceDark,
      onSurfaceVariant: onSurfaceMuted,
      surfaceDim: const Color(0xFFE8EAED),
      surfaceBright: surfaceWhite,
      surfaceContainerLowest: surfaceWhite,
      surfaceContainerLow: surfaceWhite,
      surfaceContainer: surfaceWhite,
      surfaceContainerHigh: surfaceWhite,
      surfaceContainerHighest: Color(0xFFF5F5F5),
    );

    return _buildThemeData(colorScheme, primary, secondary);
  }

  static ThemeData _buildThemeData(
    ColorScheme colorScheme,
    Color primary,
    Color secondary, {
    CustomColors customColors = CustomColors.light,
  }) {
    // brightness musí být explicitně light – některé widgety (sidebar, karty) jinak táhnou kontrast špatným směrem.
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      cardColor: Colors.white,
      scaffoldBackgroundColor: const Color(0xFFF4F5F7),
      extensions: [
        const AppThemeColors(cardColor: AppPaletteDefaults.cardColor),
        customColors,
      ],
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.grey.shade300;
            }
            if (states.contains(WidgetState.pressed)) {
              return Color.lerp(secondary, Colors.black, 0.15);
            }
            if (states.contains(WidgetState.hovered)) {
              return secondary;
            }
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.grey.shade300;
            }
            if (states.contains(WidgetState.pressed)) {
              return Color.lerp(secondary, Colors.black, 0.15);
            }
            if (states.contains(WidgetState.hovered)) {
              return secondary;
            }
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
    );
  }
}
