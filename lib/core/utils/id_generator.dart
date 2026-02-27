import 'dart:math';

/// Generátor lidsky čitelných referenčních kódů pro rezervace a úkoly.
///
/// PROČ: UUID jsou pro podporu po telefonu a CSV importy nepoužitelná. Klient potřebuje
/// krátké kódy typu "RES-A8B3K9" nebo "TSK-X7M2P4", které lze diktovat a přepisovat.
///
/// FORMAT: Prefix (RES/TSK) + pomlčka + 6 alfanumerických znaků.
/// Znaková sada vynechává matoucí znaky (O/0, I/1, L) pro snazší hláskování.
///
/// OFFLINE-FIRST: Generování probíhá na straně klienta před uložením do Supabase.
/// Při offline vytvoření se reference_number vygeneruje v Dartu a při sync se odešle.
const List<String> _safeChars = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'M', 'N', 'P', 'Q', 'R',
  'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '2', '3', '4', '5', '6', '7', '8', '9',
];

final _rng = Random();

/// Vygeneruje 6 náhodných znaků z bezpečné sady (bez O, 0, I, 1, L).
String _generateSuffix() {
  final buf = StringBuffer();
  for (var i = 0; i < 6; i++) {
    buf.write(_safeChars[_rng.nextInt(_safeChars.length)]);
  }
  return buf.toString();
}

/// Vygeneruje referenční číslo pro rezervaci (např. RES-A8B3K9).
///
/// Volat při vytváření NOVÉ rezervace před insertem do Supabase.
/// Nepoužívat pro existující záznamy – reference_number by neměl měnit.
String generateReservationRef() {
  return 'RES-${_generateSuffix()}';
}

/// Vygeneruje referenční číslo pro úkol (např. TSK-X7M2P4).
///
/// Volat při vytváření NOVÉHO úkolu před insertem do Supabase.
/// Nepoužívat pro existující záznamy – reference_number by neměl měnit.
String generateTaskRef() {
  return 'TSK-${_generateSuffix()}';
}
