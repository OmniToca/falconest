import 'package:intl/intl.dart';

/// Formát data nepřítomnosti v UI (shodně na webu i mobilu).
String formatAbsenceDate(DateTime d) {
  return DateFormat('dd.MM.yyyy').format(d);
}
