import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Geokódování textové adresy na WGS 84 souřadnice přes veřejný Nominatim (OpenStreetMap).
///
/// PROČ: Dispečer často zná jen ulici/město; ruční doplnění lat/lon z mapy je pomalé.
/// Nominatim je zdarma pro občasné dotazy z UI; hlavička [User-Agent] je povinná dle
/// zásad provozu služby (identifikace klienta FalcoNest).
class GeocodingService {
  GeocodingService();

  static const _userAgent = 'FalcoNest/1.0';

  /// Vrátí první nalezený bod nebo `null` (prázdný vstup, HTTP chyba, prázdný výsledek).
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    final q = address.trim();
    if (q.isEmpty) return null;

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeQueryComponent(q)}&format=json&limit=1',
    );

    final response = await http.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) return null;

    final first = decoded.first;
    if (first is! Map) return null;

    final lat = double.tryParse(first['lat']?.toString() ?? '');
    final lon = double.tryParse(first['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;

    return LatLng(lat, lon);
  }
}
