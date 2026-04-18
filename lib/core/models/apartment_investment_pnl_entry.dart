import 'package:freezed_annotation/freezed_annotation.dart';

import 'model_date_time_json.dart';
import 'model_numeric_json.dart';

part 'apartment_investment_pnl_entry.freezed.dart';
part 'apartment_investment_pnl_entry.g.dart';

/// Řádek tabulky `apartment_investment_pnl_entries` – měsíční souhrn příjmu nebo výdaje.
///
/// PROČ: [entryType] `income` / `expense` odpovídá CHECK v PostgreSQL; unikátní je trojice
/// (apartment_id, entry_month, entry_type) pro bezpečný upsert z klienta.
@freezed
abstract class ApartmentInvestmentPnlEntry with _$ApartmentInvestmentPnlEntry {
  const ApartmentInvestmentPnlEntry._();

  const factory ApartmentInvestmentPnlEntry({
    required String id,
    @JsonKey(name: 'apartment_id') required String apartmentId,
    /// První den měsíce (Postgres `date`).
    @JsonKey(name: 'entry_month') @IsoDateOnlyConverter() required DateTime entryMonth,
    /// `income` nebo `expense`.
    @JsonKey(name: 'entry_type') required String entryType,
    @JsonKey(fromJson: modelAmountFromJson, toJson: modelAmountToJson) @Default(0.0) double amount,
    String? description,
    @JsonKey(name: 'created_at') @NullableIsoDateTimeConverter() DateTime? createdAt,
    @JsonKey(name: 'updated_at') @NullableIsoDateTimeConverter() DateTime? updatedAt,
  }) = _ApartmentInvestmentPnlEntry;

  factory ApartmentInvestmentPnlEntry.fromJson(Map<String, dynamic> json) =>
      _$ApartmentInvestmentPnlEntryFromJson(json);
}
