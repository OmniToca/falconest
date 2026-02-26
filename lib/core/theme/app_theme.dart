import 'package:flutter/material.dart';

/// Prémiová barevná paleta FalcoNest – B2B SaaS design (2026).
///
/// Centralizované téma pro konzistentní vzhled napříč Admin, Worker a Owner portály.
/// primary = tmavě modrá, secondary = oranžový accent z loga.
const Color _primary = Color(0xFF1E3A8A);
const Color _secondary = Color(0xFFF97316);
const Color _scaffoldBackground = Color(0xFFF8FAFC);
const Color _cardColor = Color(0xFFFFFFFF);

/// Rozšíření tématu – vlastní barvy (cardColor) pro AppCard a další widgety.
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.cardColor,
  });

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

/// Centrální téma aplikace – lightTheme pro moderní SaaS vzhled.
class AppTheme {
  AppTheme._();

  /// Světlé téma s prémiovou paletou.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        primary: _primary,
        secondary: _secondary,
        surface: _cardColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: _scaffoldBackground,
      extensions: const [
        AppThemeColors(cardColor: _cardColor),
      ],
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return Colors.grey.shade300;
              }
              if (states.contains(WidgetState.pressed)) {
                return Color.lerp(_secondary, Colors.black, 0.15);
              }
              if (states.contains(WidgetState.hovered)) {
                return _secondary;
              }
              return _primary;
            },
          ),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return Colors.grey.shade300;
              }
              if (states.contains(WidgetState.pressed)) {
                return Color.lerp(_secondary, Colors.black, 0.15);
              }
              if (states.contains(WidgetState.hovered)) {
                return _secondary;
              }
              return _primary;
            },
          ),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
    );
  }
}
