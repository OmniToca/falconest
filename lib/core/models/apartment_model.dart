import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:falconest/core/constants/apartment_rental_constants.dart';
import 'package:falconest/core/utils/geo_json_point.dart';

import 'model_date_time_json.dart';
import 'model_numeric_json.dart';

part 'apartment_model.freezed.dart';
part 'apartment_model.g.dart';

/// Stav bytu z API – výchozí stejně jako u [ApartmentRow] při prázdné hodnotě.
String _apartmentStatusFromJson(Object? v) {
  const fallback = 'Uklizeno';
  if (v == null) return fallback;
  final s = (v is String ? v : v.toString()).trim();
  return s.isEmpty ? fallback : s;
}

String _checkInTimeFromJson(Object? raw) {
  final s = (raw?.toString() ?? '').trim();
  return s.isEmpty ? '15:00' : s;
}

String _checkOutTimeFromJson(Object? raw) {
  final s = (raw?.toString() ?? '').trim();
  return s.isEmpty ? '10:00' : s;
}

int _standardCleaningDurationFromJson(Object? raw) {
  if (raw == null) return 120;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString()) ?? 120;
}

String? _trimmedNullable(Object? raw) {
  if (raw == null) return null;
  final t = raw.toString().trim();
  return t.isEmpty ? null : t;
}

/// Normalizace `rental_mode` z API – neznámá hodnota → krátkodobý (bezpečný výchozí stav).
String _rentalModeFromJson(Object? v) {
  final s = (v?.toString() ?? '').trim().toLowerCase();
  if (s == kApartmentRentalModeLongTerm) return kApartmentRentalModeLongTerm;
  return kApartmentRentalModeShortTerm;
}

/// Normalizace `rent_collection_mode` – pouze notification | task (ostatní → připomínka).
String _rentCollectionModeFromJson(Object? v) {
  final s = (v?.toString() ?? '').trim().toLowerCase();
  if (s == kApartmentRentCollectionModeTask) return kApartmentRentCollectionModeTask;
  return kApartmentRentCollectionModeNotification;
}

int _rentDueDayFromJson(Object? raw) {
  if (raw == null) return 1;
  if (raw is int) return raw.clamp(1, 31);
  if (raw is num) return raw.toInt().clamp(1, 31);
  final p = int.tryParse(raw.toString().trim());
  if (p == null) return 1;
  return p.clamp(1, 31);
}

/// Řádek tabulky `apartments` z PostgREST / Supabase jako typový model.
///
/// PROČ Freezed: neměnné snapshoty při synci a typová bezpečnost; pole
/// [investmentTrackingEnabled] řídí, zda má smysl pracovat s [ApartmentInvestmentMetrics].
/// Parita s admin [ApartmentRow] – lze mapovat přes [ApartmentModel.fromJson] / toJson.
@freezed
abstract class ApartmentModel with _$ApartmentModel {
  /// Veřejný konstruktor pro rozšíření o gettery souřadnic z [geoLocation].
  const ApartmentModel._();

  const factory ApartmentModel({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    required String name,
    String? address,
    String? keybox,
    @JsonKey(name: 'parking_instructions', fromJson: _trimmedNullable) String? parkingInstructions,
    @JsonKey(name: 'review_link', fromJson: _trimmedNullable) String? reviewLink,
    @JsonKey(fromJson: _trimmedNullable) String? code,
    @JsonKey(name: 'zone_id', fromJson: _trimmedNullable) String? zoneId,
    @JsonKey(fromJson: _apartmentStatusFromJson) @Default('Uklizeno') String status,
    @JsonKey(name: 'check_in_time', fromJson: _checkInTimeFromJson) @Default('15:00') String checkInTime,
    @JsonKey(name: 'check_out_time', fromJson: _checkOutTimeFromJson) @Default('10:00') String checkOutTime,
    @JsonKey(name: 'standard_cleaning_duration', fromJson: _standardCleaningDurationFromJson) @Default(120)
    int standardCleaningDuration,
    @JsonKey(name: 'owner_notes', fromJson: _trimmedNullable) String? ownerNotes,
    @JsonKey(name: 'monthly_management_fee', fromJson: modelAmountFromJson, toJson: modelAmountToJson)
    @Default(0.0)
    double monthlyManagementFee,
    @JsonKey(name: 'managed_from') @NullableIsoDateTimeConverter() DateTime? managedFrom,
    @JsonKey(name: 'deleted_at') @NullableIsoDateTimeConverter() DateTime? deletedAt,
    @JsonKey(name: 'investment_tracking_enabled') @Default(false) bool investmentTrackingEnabled,
    /// `short_term` | `long_term` – výchozí STR pro zpětnou kompatibilitu.
    @JsonKey(name: 'rental_mode', fromJson: _rentalModeFromJson)
    @Default(kApartmentRentalModeShortTerm)
    String rentalMode,
    /// Platnost smlouvy od (jen smysl u [kApartmentRentalModeLongTerm], jinak obvykle null).
    @JsonKey(name: 'lease_start_date') @NullableIsoDateOnlyConverter() DateTime? leaseStartDate,
    /// Platnost smlouvy do.
    @JsonKey(name: 'lease_end_date') @NullableIsoDateOnlyConverter() DateTime? leaseEndDate,
    /// Měsíční nájem (dlouhodobý režim); u STR typicky 0.
    @JsonKey(name: 'rent_amount', fromJson: modelAmountFromJson, toJson: modelAmountToJson)
    @Default(0.0)
    double rentAmount,
    /// Den splatnosti v měsíci (1–31) – musí odpovídat CHECK v Supabase.
    @JsonKey(name: 'rent_due_day', fromJson: _rentDueDayFromJson) @Default(1) int rentDueDay,
    /// Připomínka v aplikaci vs. úkol pro pracovníka (`rent_collection`).
    @JsonKey(name: 'rent_collection_mode', fromJson: _rentCollectionModeFromJson)
    @Default(kApartmentRentCollectionModeNotification)
    String rentCollectionMode,
    /// Kdo má úkol výběru nájmu (profiles.id), jen pro [kApartmentRentCollectionModeTask].
    @JsonKey(name: 'rent_task_assignee_id', fromJson: _trimmedNullable) String? rentTaskAssigneeId,
    /// Raw GeoJSON z `geo_location` – pro serializaci zpět použijte [GeoJsonPoint.toPostgrestJson].
    @JsonKey(name: 'geo_location') Object? geoLocation,
  }) = _ApartmentModel;

  factory ApartmentModel.fromJson(Map<String, dynamic> json) => _$ApartmentModelFromJson(json);

  /// Zeměpisná šířka z [geoLocation], pokud je platný GeoJSON Point.
  double? get latitude => GeoJsonPoint.parseFromPostgrest(geoLocation)?.latitude;

  /// Zeměpisná délka z [geoLocation].
  double? get longitude => GeoJsonPoint.parseFromPostgrest(geoLocation)?.longitude;
}
