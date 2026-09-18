/// Validace dokladů RD 933/2021 / SES (NIF, NIE, pas).
///
/// PROČ: SES často vrací reject na špatné 2. příjmení u Španělů nebo na neplatný NIE.
/// Chceme chytit zjevné chyby v UI, ne až po SOAP.
class LegalDocumentValidators {
  LegalDocumentValidators._();

  static final _nifRe = RegExp(r'^[0-9]{8}[A-Z]$');
  static final _nieRe = RegExp(r'^[XYZ][0-9]{7}[A-Z]$');
  static final _pasRe = RegExp(r'^[A-Z0-9]{5,15}$');

  /// Kontrolní písmeno DNI/NIF (modulo 23).
  static const _nifLetters = 'TRWAGMYFPDXBNJZSQVHLCKE';

  static String normalize(String raw) =>
      raw.trim().toUpperCase().replaceAll(' ', '');

  static bool isValidNif(String raw) {
    final v = normalize(raw);
    if (!_nifRe.hasMatch(v)) return false;
    final num = int.tryParse(v.substring(0, 8));
    if (num == null) return false;
    return v[8] == _nifLetters[num % 23];
  }

  static bool isValidNie(String raw) {
    final v = normalize(raw);
    if (!_nieRe.hasMatch(v)) return false;
    final prefix = v[0] == 'X'
        ? '0'
        : v[0] == 'Y'
        ? '1'
        : '2';
    return isValidNif('$prefix${v.substring(1)}');
  }

  static bool isValidPassport(String raw) {
    final v = normalize(raw);
    return _pasRe.hasMatch(v);
  }

  /// Druhé příjmení je u NIF/NIE v praxi SES povinné (Španělé / NIE).
  static bool requiresSecondLastName(String? documentType) {
    final t = documentType?.trim().toUpperCase();
    return t == 'NIF' || t == 'NIE';
  }

  static bool isValidForType(String? documentType, String raw) {
    switch (documentType?.trim().toUpperCase()) {
      case 'NIF':
        return isValidNif(raw);
      case 'NIE':
        return isValidNie(raw);
      case 'PAS':
        return isValidPassport(raw);
      case 'OTRO':
        return normalize(raw).length >= 4;
      default:
        return normalize(raw).isNotEmpty;
    }
  }
}
