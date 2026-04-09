import 'package:json_annotation/json_annotation.dart';

/// Pomocné převody pro Supabase JSON (ISO řetězce → DateTime).
///
/// PROČ: PostgREST vrací timestamptz často jako řetězec; json_serializable
/// bez converteru by typ nezvládl.

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
