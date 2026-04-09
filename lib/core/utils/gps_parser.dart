import 'package:latlong2/latlong.dart';

/// Parsování „vloženého“ textu GPS z Mapy.cz, Google Maps apod. do [LatLng].
///
/// PROČ: Uživatelé kopírují formáty jako `38.0539500N, 0.7401433W` nebo `38.053, -0.740`;
/// dvě samostatná číselná pole nutí text ručně dělit a řešit znaménka. Jedno pole
/// + tato funkce snižuje chybovost a zrychluje práci dispečera.
///
/// Pravidla:
/// - První hodnota = **zeměpisná šířka**, druhá = **zeměpisná délka** (běžné pořadí z map).
/// - `N` / `S` u šířky: sever kladně, západně záporně (`S` → záporná šířka).
/// - `E` / `W` u délky: východ kladně, západ záporně (`W` → záporná délka).
/// - Oddělovač dvou čísel: čárka nebo mezery (tabulátor apod.).
LatLng? parseSmartGpsString(String input) {
  final t = input.trim();
  if (t.isEmpty) return null;

  final parts = _splitIntoTwoCoordinateTokens(t);
  if (parts == null) return null;

  final lat = _parseSingleCoordinateToken(parts[0], isLatitude: true);
  final lon = _parseSingleCoordinateToken(parts[1], isLatitude: false);
  if (lat == null || lon == null) return null;

  // Rozsah WGS 84 neřešíme zde – [GeoJsonPoint.validateOptionalSmartGpsText] vrátí
  // konkrétní lokalizovanou chybu (šířka vs. délka), aby uživatel věděl, co opravit.
  return LatLng(lat, lon);
}

/// Rozdělí vstup na přesně dva tokeny (lat, lon).
///
/// Nejdřív zkusíme rozdělení **čárkou** (bez ohledu na mezery kolem). Pokud to nedá
/// dva segmenty, zkusíme **libovolné bílé znaky** mezi tokeny.
List<String>? _splitIntoTwoCoordinateTokens(String t) {
  if (t.contains(',')) {
    final commaParts = t
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (commaParts.length == 2) return commaParts;
  }

  final spaceParts = t.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (spaceParts.length == 2) return spaceParts;

  return null;
}

/// Parsuje jeden token (např. `38.0539500N`, `-0.7401433`, `0.7401433W`).
double? _parseSingleCoordinateToken(String raw, {required bool isLatitude}) {
  var s = raw.trim();
  if (s.isEmpty) return null;

  // Volitelné směrové písmeno na konci (Mapy.cz / některé exporty).
  String? dir;
  final last = s[s.length - 1];
  if (RegExp(r'^[NnSsEeWw]$').hasMatch(last)) {
    dir = last.toUpperCase();
    s = s.substring(0, s.length - 1).trim();
  }

  // Desetinná čárka uvnitř čísla → tečka pro double.tryParse.
  s = s.replaceAll(',', '.');

  final v = double.tryParse(s);
  if (v == null) return null;

  if (dir != null) {
    // N/E = kladná polokoule podle typu; S/W = záporná (velikost z absolutní hodnoty čísla).
    switch (dir) {
      case 'N':
        if (!isLatitude) return null;
        return v.abs();
      case 'S':
        if (!isLatitude) return null;
        return -v.abs();
      case 'E':
        if (isLatitude) return null;
        return v.abs();
      case 'W':
        if (isLatitude) return null;
        return -v.abs();
      default:
        return null;
    }
  }

  return v;
}
