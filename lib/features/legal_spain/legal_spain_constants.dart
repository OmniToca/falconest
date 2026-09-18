/// Klíč katalogového modulu check-in + SES Hospedajes (RD 933/2021).
///
/// PROČ: Agentura platí za byt (`per_apartment`). Bez aktivního `tenant_modules`
/// se nesmí odesílat SOAP ani veřejný `/checkin` – jinak by se paywall obešel odkazem.
const String kLegalSpainModuleKey = 'legal_spain';

/// Stavy session check-inu / komunikace se SES – semafor v UI.
const List<String> kLegalCheckinStatuses = [
  'draft',
  'queued',
  'accepted',
  'reported',
  'rejected',
  'timeout',
];

/// Typy dokladů dle katalogu SES (zjednodušená sada pro VUT / Valencijsko).
const List<String> kLegalDocumentTypes = ['NIF', 'NIE', 'PAS', 'OTRO'];

/// Pohlaví v SOAP (M/F).
const List<String> kLegalSexValues = ['M', 'F'];

/// Výchozí typy platby v PV (kód SES).
const List<String> kLegalPaymentTypes = [
  'EFECTIVO',
  'TARJETA',
  'TRANSFERENCIA',
  'PLATAFORMA',
  'OTRO',
];

/// OTA, které RH (smlouvu) posílají samy – FalcoNest posílá jen PV (hosty).
const Set<String> kOtaReservationSources = {'Booking', 'Airbnb'};

/// True, pokud musíme na SES poslat komunikaci RH (přímá rezervace / neznámý zdroj).
bool reservationSourceRequiresRh(String? source) {
  final s = source?.trim();
  if (s == null || s.isEmpty) return true;
  return !kOtaReservationSources.contains(s);
}
