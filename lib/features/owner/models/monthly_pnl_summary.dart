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
    /// Datum skutečného výběru / potvrzení nájmu (dlouhodobý pronájem) – hotovost / P&L.
    DateTime? rentPaidAt,
    /// Plánovaný termín výběru ([tasks.due_date], rent_collection).
    DateTime? rentPlannedCollectionDate,
    /// Skutečné dokončení ([tasks.completed_at] nebo potvrzení převodu).
    DateTime? rentActualCollectionDate,
    /// Bilance nájmu po FIFO amortizaci napříč měsíci (alokované platby − očekáváno).
    /// null = bez kontextu nájmu nebo měsíc kauce.
    double? rentBalanceDifference,
    /// Částka kauce z P&L (`description` obsahuje „Kauce“) – nezapočítává se do [rentBalanceDifference].
    double? rentDepositAmount,
    /// Částka z FIFO poolu alokovaná na tento měsíc (pro vysvětlení úhrady z minula).
    @Default(0.0) double rentFifoAllocatedFromPool,
    /// True = část úhrady šla z historických plateb, ne jen z výběru v tomto měsíci.
    @Default(false) bool rentCoveredFromPreviousPool,
  }) = _MonthlyPnlSummary;
}
