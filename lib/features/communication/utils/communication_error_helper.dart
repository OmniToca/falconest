// Pomocná funkce pro zobrazení chyb z modulu Komunikace v UI.
// Výjimky z repository/notifieru mohou nést i18n klíč (např. communication.error_no_tenant).
// Pokud ano, vrátí přeložený text; jinak surový toString().

import 'package:easy_localization/easy_localization.dart';

/// Vrátí uživatelsky zobrazitelný text chyby. Pokud [error] je StateError
/// s message začínajícím na 'communication.' nebo 'common.', přeloží klíč přes .tr().
String userFacingCommunicationError(Object? error) {
  if (error == null) return '';
  if (error is StateError) {
    final k = error.message;
    if (k.startsWith('communication.') || k.startsWith('common.')) {
      return k.tr();
    }
  }
  return error.toString();
}
