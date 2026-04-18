import 'package:freezed_annotation/freezed_annotation.dart';

part 'monthly_pnl_summary.freezed.dart';

/// Měsíční souhrn P&L pro investiční výsledovku majitele (manuální řádky + agentura).
///
/// PROČ: Jeden přehledový model pro tabulku a ROI – [ownerIncome]/[ownerExpense] jdou z
/// `apartment_investment_pnl_entries`, [agencyCosts] z uzamčených `billing_snapshots`
/// (úkoly s plátcem majitel + poměrný díl měsíčního paušálu dle `apartments.monthly_management_fee`).
@freezed
abstract class MonthlyPnlSummary with _$MonthlyPnlSummary {
  const MonthlyPnlSummary._();

  const factory MonthlyPnlSummary({
    /// První den kalendářního měsíce (UTC), konzistentně s P&L záznamy v DB.
    required DateTime month,
    @Default(0.0) double ownerIncome,
    @Default(0.0) double ownerExpense,
    /// Částka vyúčtovaná agenturou za tento byt a měsíc (0 = žádný uzamčený snapshot).
    @Default(0.0) double agencyCosts,
  }) = _MonthlyPnlSummary;
}
