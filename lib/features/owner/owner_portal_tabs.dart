/// Indexy záložek v [OwnerLayout] – musí přesně odpovídat pořadí `IndexedStack` children.
///
/// PROČ: Přepnutí záložky z nástěnky (např. „Spravovat hotovost“ → Vyúčtování) přes sdílený provider.
abstract final class OwnerPortalTabIndex {
  static const int dashboard = 0;
  static const int apartments = 1;
  static const int reservations = 2;
  static const int tasks = 3;
  static const int calendar = 4;
  static const int billing = 5;
  static const int settings = 6;
  /// Check-in / SES – na konci stacku, aby se neremappovaly záložky 0–6.
  static const int legalSpain = 7;
}
