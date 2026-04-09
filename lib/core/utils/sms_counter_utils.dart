import 'package:characters/characters.dart';

/// Výsledek analýzy textu pro účely SMS (GSM-7 vs UCS-2 a počet segmentů).
///
/// PROČ: Operátoři účtují po segmentech; UI musí ukázat stejná čísla jako síť.
class SmsCountResult {
  const SmsCountResult({
    required this.isUnicode,
    required this.characterCount,
    required this.smsSegments,
  });

  /// `true`, pokud zpráva nemůže být kódována GSM-7 (diakritika, emoji, znaky mimo tabulku).
  final bool isUnicode;

  /// Počet znaků pro zobrazení uživateli (grapheme clustery – viz [Characters]).
  /// PROČ: Emoji se počítá jako jeden „znak“ v UI, i když UCS-2 bere 2 UTF-16 jednotky.
  final int characterCount;

  /// Počet zpoplatněných SMS segmentů podle GSM pravidel níže.
  final int smsSegments;
}

/// Utility pro výpočet segmentů SMS podle běžných pravidel GSM / UCS-2.
///
/// PRAVIDLA (sjednocená s požadavkem produktu):
/// - **GSM-7**: pokud lze celý text zakódovat do 7bitové abecedy GSM 03.38
///   (základní znaky + rozšířené znaky účtované jako 2 septety).
///   - 1 segment = max **160** septetů.
///   - U více segmentů (concatenated SMS) první „hlavička“ bere 7 septetů z každého
///     následujícího bloku → efektivně **153** septetů na další segment.
/// - **UCS-2 (Unicode)**: stačí jeden znak mimo GSM (např. česká diakritika, emoji).
///   - 1 segment = max **70** UTF-16 kódových jednotek (standardní UCS-2 PDU).
///   - U více segmentů opět rezerva hlavičky → **67** znaků na další segment.
///
/// PROČ: Bez tohoto rozlišení by uživatel při přidání jednoho „á“ nepochopil pokles limitu.
class SmsCounterUtils {
  SmsCounterUtils._();

  /// Maximální délka prvního GSM segmentu (septety).
  static const int gsmSingleMax = 160;

  /// Délka každého dalšího GSM segmentu po rozdělení (po odečtu hlavičky UDH).
  static const int gsmMultipartUnit = 153;

  /// Maximální délka prvního UCS-2 segmentu (UTF-16 code units).
  static const int ucs2SingleMax = 70;

  /// Délka každého dalšího UCS-2 segmentu po rozdělení.
  static const int ucs2MultipartUnit = 67;

  /// Základní GSM 7-bit tabulka (1 septet na znak) – 3GPP TS 23.038.
  static const String _kGsmBasicChars =
      '@£\$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞ ÆæßÉ !"#¤%&\'()*+,-./0123456789:;<=>?¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà';

  /// Rozšířená GSM tabulka (escape + znak = 2 septety).
  static const Set<String> _kGsmExtendedChars = {
    '^',
    '€',
    '{',
    '}',
    '\\',
    '|',
    '[',
    ']',
    '~',
  };

  static final Set<String> _kGsmBasicSet = _kGsmBasicChars.characters.toSet();

  /// Analyzuje [text] a vrátí kódování + počet segmentů.
  static SmsCountResult analyze(String text) {
    final graphemeCount = text.characters.length;
    if (text.isEmpty) {
      return const SmsCountResult(isUnicode: false, characterCount: 0, smsSegments: 0);
    }

    final gsmSeptets = _tryGsmSeptetLength(text);
    if (gsmSeptets != null) {
      return SmsCountResult(
        isUnicode: false,
        characterCount: graphemeCount,
        smsSegments: _segmentsFromGsmSeptets(gsmSeptets),
      );
    }

    final utf16Units = text.length;
    return SmsCountResult(
      isUnicode: true,
      characterCount: graphemeCount,
      smsSegments: _segmentsFromUtf16Units(utf16Units),
    );
  }

  /// Vrátí celkový počet septetů pro GSM-7, nebo `null` pokud text GSM nepodporuje.
  ///
  /// PROČ: Znaky z rozšířené tabulky (např. `^`, `€`) berou 2 septety – musí se započítat,
  /// jinak by segmenty neodpovídaly skutečnému PDU.
  static int? _tryGsmSeptetLength(String text) {
    var septets = 0;
    for (final r in text.runes) {
      final ch = String.fromCharCode(r);
      if (_kGsmBasicSet.contains(ch)) {
        septets += 1;
      } else if (_kGsmExtendedChars.contains(ch)) {
        septets += 2;
      } else {
        return null;
      }
    }
    return septets;
  }

  /// Počet GSM segmentů z celkového počtu septetů (160 / 153 / 153…).
  static int _segmentsFromGsmSeptets(int septets) {
    if (septets <= 0) return 0;
    if (septets <= gsmSingleMax) return 1;
    final remainder = septets - gsmSingleMax;
    return 1 + (remainder + gsmMultipartUnit - 1) ~/ gsmMultipartUnit;
  }

  /// Počet UCS-2 segmentů z délky UTF-16 (70 / 67 / 67…).
  static int _segmentsFromUtf16Units(int utf16Length) {
    if (utf16Length <= 0) return 0;
    if (utf16Length <= ucs2SingleMax) return 1;
    final remainder = utf16Length - ucs2SingleMax;
    return 1 + (remainder + ucs2MultipartUnit - 1) ~/ ucs2MultipartUnit;
  }
}
