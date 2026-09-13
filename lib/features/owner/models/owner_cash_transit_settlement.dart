import 'package:freezed_annotation/freezed_annotation.dart';

import 'owner_json_converters.dart';

part 'owner_cash_transit_settlement.freezed.dart';
part 'owner_cash_transit_settlement.g.dart';

/// Řádek tabulky `owner_cash_transit_settlements` – uznaná průtoková hotovost za pobyt.
///
/// PROČ Freezed: typová bezpečnost při čtení z Supabase místo `Map<String, dynamic>`;
/// kompatibilní se základní migrací `20260404120000` (`note`, `created_by`, bez `status` / `settled_by` / `employee_cash_transaction_id`)
/// i s rozšířenými instancemi, kde tyto sloupce existují.
@freezed
abstract class OwnerCashTransitSettlement with _$OwnerCashTransitSettlement {
  const OwnerCashTransitSettlement._();

  const factory OwnerCashTransitSettlement({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'reservation_id') String? reservationId,
    @JsonKey(name: 'apartment_id') String? apartmentId,
    @JsonKey(name: 'task_id') String? taskId,
    @JsonKey(fromJson: amountFromJson, toJson: amountToJson) required double amount,
    @Default('EUR') String currency,
    @JsonKey(name: 'settled_at') @NullableIsoDateTimeConverter() DateTime? settledAt,
    @JsonKey(name: 'settled_by') String? settledBy,
    /// V rozšířené DB může být CHECK; jinak výchozí `available` (majitel nefiltruje podle DB sloupce).
    @Default('available') String status,
    @JsonKey(name: 'employee_cash_transaction_id') String? employeeCashTransactionId,
    @JsonKey(name: 'note') String? notes,
    @JsonKey(name: 'created_at') @NullableIsoDateTimeConverter() DateTime? createdAt,
    @JsonKey(name: 'updated_at') @NullableIsoDateTimeConverter() DateTime? updatedAt,
    /// Začátek pobytu z `reservations.start_date` – doplní repozitář při výpisu pro majitele; není v JSON odpovědi settlements.
    @JsonKey(includeFromJson: false, includeToJson: false) DateTime? reservationStayStart,
    /// Konec pobytu z `reservations.end_date` (viz [reservationStayStart]).
    @JsonKey(includeFromJson: false, includeToJson: false) DateTime? reservationStayEnd,
    /// Jméno hosta z `reservations.guest_name` – doplní repozitář pro dropdown dispozice.
    @JsonKey(includeFromJson: false, includeToJson: false) String? guestName,
    /// Reálně dostupná částka pro novou žádost (po odečtení rezervací z `owner_cash_disposition_requests`).
    @JsonKey(includeFromJson: false, includeToJson: false) double? availableAmount,
  }) = _OwnerCashTransitSettlement;

  factory OwnerCashTransitSettlement.fromJson(Map<String, dynamic> json) =>
      _$OwnerCashTransitSettlementFromJson(json);

  /// Částka pro formulář dispozice – [availableAmount] z repozitáře, jinak surové [amount] z DB.
  double get amountForDisposition => availableAmount ?? amount;
}
