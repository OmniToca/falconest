import 'package:falconest/core/utils/gps_parser.dart';

/// Pomůcky pro sloupec PostGIS `geo_location` přes PostgREST.
///
/// PROČ: Supabase vrací geometrii jako GeoJSON (`type: Point`, `coordinates: [lon, lat]`).
/// Aplikace v Dartu pracuje se `latitude` / `longitude`; při zápisu musíme složit validní GeoJSON,
/// jinak PostgREST geometrii nepřijme.
class GeoJsonPoint {
  GeoJsonPoint._();

  /// Worker navigace: nejdřív bod přiřazený k úkolu, jinak k bytu (stejný sloupec `geo_location` v obou tabulkách).
  ///
  /// PROČ: Dispečink může mít přesnější místo výkonu na úrovni úkolu; když chybí, spadneme na polohu apartmánu.
  static ({double latitude, double longitude})? workerGpsFromTaskThenApartment({
    required dynamic taskGeoRaw,
    required dynamic apartmentGeoRaw,
  }) {
    final fromTask = parseFromPostgrest(taskGeoRaw);
    if (fromTask != null) return fromTask;
    return parseFromPostgrest(apartmentGeoRaw);
  }

  /// Čte GeoJSON bod z odpovědi API. [coordinates] je v pořadí **[zeměpisná délka, zeměpisná šířka]**.
  static ({double latitude, double longitude})? parseFromPostgrest(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    if (m['type']?.toString() != 'Point') return null;
    final c = m['coordinates'];
    if (c is! List || c.length < 2) return null;
    final lon = (c[0] as num?)?.toDouble();
    final lat = (c[1] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return (latitude: lat, longitude: lon);
  }

  /// Hodnota pro `geo_location` v insert/update (PostgREST → PostGIS).
  static Map<String, dynamic>? toPostgrestJson(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    return <String, dynamic>{
      'type': 'Point',
      'coordinates': <double>[longitude, latitude],
    };
  }

  /// Validace dvou textových polí ve formuláři: obě prázdná = OK; obě vyplněná a v rozsahu = OK; jinak chybový klíč pro `.tr()`.
  static String? validateOptionalPairText(String latRaw, String lngRaw) {
    final lt = latRaw.trim();
    final ln = lngRaw.trim();
    if (lt.isEmpty && ln.isEmpty) return null;
    if (lt.isEmpty || ln.isEmpty) return 'admin.geo_both_or_none';
    final lat = double.tryParse(lt.replaceAll(',', '.'));
    final lng = double.tryParse(ln.replaceAll(',', '.'));
    if (lat == null || lng == null) return 'admin.geo_invalid_number';
    if (lat < -90 || lat > 90) return 'admin.geo_latitude_range';
    if (lng < -180 || lng > 180) return 'admin.geo_longitude_range';
    return null;
  }

  /// Po úspěšné validaci vrátí čísla; jinak null.
  static ({double latitude, double longitude})? tryParsePairText(String latRaw, String lngRaw) {
    if (validateOptionalPairText(latRaw, lngRaw) != null) return null;
    final lat = double.parse(latRaw.trim().replaceAll(',', '.'));
    final lng = double.parse(lngRaw.trim().replaceAll(',', '.'));
    return (latitude: lat, longitude: lng);
  }

  /// Validace jednoho textového pole „chytrých“ GPS (Mapy.cz, Google, …).
  ///
  /// PROČ: Prázdné pole = bez geolokace (OK). Ne-prázdné musí projít [parseSmartGpsString]
  /// a být v platném rozsahu WGS 84 – jinak vracíme klíč pro `.tr()`.
  static String? validateOptionalSmartGpsText(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final ll = parseSmartGpsString(t);
    if (ll == null) return 'admin.geo_invalid_coordinate_format';
    if (ll.latitude < -90 || ll.latitude > 90) return 'admin.geo_latitude_range';
    if (ll.longitude < -180 || ll.longitude > 180) return 'admin.geo_longitude_range';
    return null;
  }

  /// Parsování jednoho pole po úspěšné validaci – pro uložení do DB / modelu.
  static ({double latitude, double longitude})? tryParseSmartGpsText(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final ll = parseSmartGpsString(t);
    if (ll == null) return null;
    if (ll.latitude < -90 || ll.latitude > 90) return null;
    if (ll.longitude < -180 || ll.longitude > 180) return null;
    return (latitude: ll.latitude, longitude: ll.longitude);
  }
}
