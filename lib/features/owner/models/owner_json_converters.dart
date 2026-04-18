import 'package:json_annotation/json_annotation.dart';

/// ISO řetězce z PostgREST → nullable DateTime (stejný princip jako u checklist modelů).
class NullableIsoDateTimeConverter implements JsonConverter<DateTime?, Object?> {
  const NullableIsoDateTimeConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    if (json is DateTime) return json;
    if (json is String) return DateTime.tryParse(json);
    return null;
  }

  @override
  Object? toJson(DateTime? object) => object?.toIso8601String();
}

/// Povinný timestamptz z API (např. created_at NOT NULL).
class IsoDateTimeConverter implements JsonConverter<DateTime, Object?> {
  const IsoDateTimeConverter();

  @override
  DateTime fromJson(Object? json) {
    if (json is DateTime) return json;
    if (json is String) {
      final d = DateTime.tryParse(json);
      if (d != null) return d;
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  @override
  Object? toJson(DateTime object) => object.toIso8601String();
}

/// numeric / int / String z PostgREST → double (částky).
double amountFromJson(Object? json) {
  if (json == null) return 0;
  if (json is num) return json.toDouble();
  return double.tryParse(json.toString()) ?? 0;
}

Object? amountToJson(double value) => value;
