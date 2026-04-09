/// Jedna položka katalogu podporovaných jazyků komunikace.
///
/// [code] = ISO kód jazyka (`cs`, `en` ...), `null` znamená „výchozí“.
/// [labelKey] = i18n klíč pro zobrazovaný název v UI.
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.labelKey,
  });

  final String? code;
  final String labelKey;
}

/// Centrální katalog jazyků pro komunikační modul.
///
/// PROČ: Single Source of Truth pro dropdowny rezervací i šablon, aby
/// se seznam jazyků nerozjížděl mezi různými dialogy.
abstract final class SupportedLanguages {
  static const all = <AppLanguage>[
    AppLanguage(code: null, labelKey: 'communication.template_language_default'),
    AppLanguage(code: 'cs', labelKey: 'communication.template_language_cs'),
    AppLanguage(code: 'en', labelKey: 'communication.template_language_en'),
    AppLanguage(code: 'es', labelKey: 'communication.template_language_es'),
    AppLanguage(code: 'de', labelKey: 'communication.template_language_de'),
    AppLanguage(code: 'fr', labelKey: 'communication.template_language_fr'),
  ];
}

