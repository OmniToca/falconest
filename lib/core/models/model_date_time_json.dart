import 'package:json_annotation/json_annotation.dart';

/// ISO řetězce z PostgREST → nullable [DateTime] (UTC kde jde).
///
/// PROČ: Sdílená definice v `core/models` místo importu z feature modulů (clean layering).
class NullableIsoDateTimeConverter implements JsonConverter<DateTime?, Object?> {
  const NullableIsoDateTimeConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    if (json is DateTime) return json.toUtc();
    if (json is String) return DateTime.tryParse(json)?.toUtc();
    return null;
  }

  @override
  Object? toJson(DateTime? object) => object?.toIso8601String();
}

/// Povinný timestamptz z API.
class IsoDateTimeConverter implements JsonConverter<DateTime, Object?> {
  const IsoDateTimeConverter();

  @override
  DateTime fromJson(Object? json) {
    if (json is DateTime) return json.toUtc();
    if (json is String) {
      final d = DateTime.tryParse(json);
      if (d != null) return d.toUtc();
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  @override
  Object? toJson(DateTime object) => object.toIso8601String();
}

/// Sloupec PostgreSQL `date` (YYYY-MM-DD) – normalizace na UTC půlnoc dne.
///
/// PROČ: PostgREST vrací `entry_month` jako řetězec bez času; pro výpočty v aplikaci
/// držíme konzistentní kalendářní den v UTC.
class IsoDateOnlyConverter implements JsonConverter<DateTime, Object?> {
  const IsoDateOnlyConverter();

  @override
  DateTime fromJson(Object? json) {
    if (json == null) return DateTime.utc(1970, 1, 1);
    if (json is DateTime) return DateTime.utc(json.year, json.month, json.day);
    if (json is String) {
      final d = DateTime.tryParse(json);
      if (d != null) return DateTime.utc(d.year, d.month, d.day);
    }
    return DateTime.utc(1970, 1, 1);
  }

  @override
  Object? toJson(DateTime object) =>
      '${object.year.toString().padLeft(4, '0')}-'
      '${object.month.toString().padLeft(2, '0')}-'
      '${object.day.toString().padLeft(2, '0')}';
}

/// PostgreSQL `date` (nullable) – normalizace na UTC půlnoc dne.
///
/// PROČ: Parita s `lease_start_date` / `lease_end_date` u apartmánů; PostgREST vrací `YYYY-MM-DD`.
class NullableIsoDateOnlyConverter implements JsonConverter<DateTime?, Object?> {
  const NullableIsoDateOnlyConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    if (json is DateTime) return DateTime.utc(json.year, json.month, json.day);
    if (json is String) {
      final d = DateTime.tryParse(json);
      if (d != null) return DateTime.utc(d.year, d.month, d.day);
    }
    return null;
  }

  @override
  Object? toJson(DateTime? object) {
    if (object == null) return null;
    return '${object.year.toString().padLeft(4, '0')}-'
        '${object.month.toString().padLeft(2, '0')}-'
        '${object.day.toString().padLeft(2, '0')}';
  }
}
