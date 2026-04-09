/// Centrální mezery Design Systému FalcoNest (padding/margin).
///
/// PROČ: Jednotné odsazení místo „magických čísel“ v UI; snadná migrace
/// existujících obrazovek postupným nahrazováním `EdgeInsets` hodnotami z [AppSpacing].
class AppSpacing {
  AppSpacing._();

  /// 4.0 – velmi těsné rozestupy (ikona–text v kompaktních řádcích).
  static const double xs = 4.0;

  /// 8.0 – standardní malý rozestup mezi souvisejícími prvky.
  static const double sm = 8.0;

  /// 16.0 – výchozí vnitřní okraj karet a sekcí.
  static const double md = 16.0;

  /// 24.0 – větší oddělení bloků obsahu.
  static const double lg = 24.0;

  /// 32.0 – sekční mezery, prázdné stavy.
  static const double xl = 32.0;

  /// 48.0 – velké vertikální oddělení (hero sekce, empty state).
  static const double xxl = 48.0;
}
