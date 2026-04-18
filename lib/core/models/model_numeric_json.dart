// Pomocné funkce pro json_serializable u čísel z PostgREST (numeric, int, String).
// PROČ: Stejný princip jako u owner modelů – API vrací numeric jako String nebo num;
// sjednocení bez závislosti feature složek na sebe navzájem.

double modelAmountFromJson(Object? json) {
  if (json == null) return 0;
  if (json is num) return json.toDouble();
  return double.tryParse(json.toString()) ?? 0;
}

Object? modelAmountToJson(double value) => value;

/// `integer` / num / String z API → nullable int (např. standard_cleaning_duration).
int? modelIntNullableFromJson(Object? json) {
  if (json == null) return null;
  if (json is int) return json;
  if (json is num) return json.toInt();
  return int.tryParse(json.toString());
}

Object? modelIntNullableToJson(int? value) => value;
