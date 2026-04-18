import 'package:freezed_annotation/freezed_annotation.dart';

import 'owner_json_converters.dart';

part 'owner_cash_disposition_request.freezed.dart';
part 'owner_cash_disposition_request.g.dart';

/// Řádek `owner_cash_disposition_requests` – žádost majitele o způsob vyřízení hotovosti.
///
/// PROČ: Oddělení procesu od faktu uznané částky (`OwnerCashTransitSettlement`);
/// [settlementId] vždy ukazuje na konkrétní settlement (DB constraint + RLS).
@freezed
abstract class OwnerCashDispositionRequest with _$OwnerCashDispositionRequest {
  const OwnerCashDispositionRequest._();

  const factory OwnerCashDispositionRequest({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    @JsonKey(name: 'settlement_id') required String settlementId,
    @JsonKey(name: 'owner_profile_id') required String ownerProfileId,
    /// `bank_transfer` | `invoice_credit` | `vault_pickup`
    @JsonKey(name: 'disposition_type') required String dispositionType,
    @JsonKey(fromJson: amountFromJson, toJson: amountToJson) required double amount,
    /// Již uplatněná část žádosti (umoření atd., migrace `20260410010000`).
    @JsonKey(name: 'used_amount', fromJson: amountFromJson, toJson: amountToJson)
    @Default(0.0)
    double usedAmount,
    /// `pending` | `approved` | `rejected` | `completed` | `partially_completed` | `ready_for_pickup`
    required String status,
    /// IBAN / číslo účtu u `bank_transfer` (volitelné, migrace `20260410000000`).
    String? iban,
    /// Plánované vyzvednutí u `vault_pickup` (migrace `20260410020000`).
    @JsonKey(name: 'pickup_date') @NullableIsoDateTimeConverter() DateTime? pickupDate,
    @JsonKey(name: 'admin_notes') String? adminNotes,
    @JsonKey(name: 'created_at') @IsoDateTimeConverter() required DateTime createdAt,
    @JsonKey(name: 'updated_at') @IsoDateTimeConverter() required DateTime updatedAt,
  }) = _OwnerCashDispositionRequest;

  factory OwnerCashDispositionRequest.fromJson(Map<String, dynamic> json) =>
      _$OwnerCashDispositionRequestFromJson(json);
}
