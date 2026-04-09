import 'package:url_launcher/url_launcher.dart';

/// Sestaví odkaz Google Maps Search ve formátu používaném ve Worker UI (`/search/?api=1&query=…`).
///
/// PROČ: Parametr `lat,lon` vede přímo na přesný bod WGS 84; textová adresa zůstává fallbackem,
/// když z API (nebo offline Drift bez geo sloupců) souřadnice nejsou k dispozici.
Uri workerGoogleMapsSearchUri({
  required bool hasGps,
  double? latitude,
  double? longitude,
  required String addressFallback,
}) {
  final queryPart = hasGps && latitude != null && longitude != null
      ? '$latitude,$longitude'
      : addressFallback.trim();
  if (queryPart.isEmpty) {
    return Uri.parse('https://www.google.com/maps/');
  }
  return Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(queryPart)}',
  );
}

/// Otevře Maps v externí aplikaci – stejné jako dříve `launchUrl` + `LaunchMode.externalApplication`.
Future<void> launchWorkerGoogleMapsSearch({
  required bool hasGps,
  double? latitude,
  double? longitude,
  required String addressFallback,
}) async {
  final uri = workerGoogleMapsSearchUri(
    hasGps: hasGps,
    latitude: latitude,
    longitude: longitude,
    addressFallback: addressFallback,
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
