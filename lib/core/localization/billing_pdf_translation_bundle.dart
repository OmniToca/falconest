import 'dart:convert';

import 'package:flutter/services.dart';

/// Načítá překlady pro PDF podkladů z **týchž JSON souborů** jako EasyLocalization (`assets/translations/{kód}.json`).
///
/// **PROČ nevoláme `.tr(locale: …)`:** V easy_localization 3.0.x nemá řetězcové `.tr()` parametr `locale`.
/// Dočasná změna `context.setLocale()` by navíc přepsala jazyk celé aplikace (a často i uloženou preferenci).
/// Čtení konkrétního jazykového souboru z assetů dává stejné řetězce jako runtime i18n, ale izolovaně pro export.
class BillingPdfTranslationBundle {
  BillingPdfTranslationBundle._(this._root);

  final Map<String, dynamic> _root;

  static final Map<String, Future<BillingPdfTranslationBundle>> _cache = {};

  /// [languageCode] musí odpovídat názvu souboru (`cs`, `en`, `es`).
  static Future<BillingPdfTranslationBundle> load(String languageCode) {
    final code = languageCode.trim().toLowerCase();
    return _cache.putIfAbsent(code, () async {
      final raw = await rootBundle.loadString('assets/translations/$code.json');
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Neočekávaný tvar překladů pro $code.json');
      }
      return BillingPdfTranslationBundle._(decoded);
    });
  }

  /// Vyhodnotí tečkový klíč (`admin.finance.billing_client_label`).
  ///
  /// **PROČ bez fallbacku:** Chybějící klíč má selhat hlasitě při vývoji/testu, ne tiše vytisknout anglický text z kódu.
  String tr(String key) {
    final parts = key.split('.');
    dynamic node = _root;
    for (final p in parts) {
      if (node is! Map || !node.containsKey(p)) {
        throw StateError('Chybí překladový klíč v $key (locale bundle)');
      }
      node = node[p];
    }
    if (node is String) return node;
    throw StateError('Klíč $key není řetězec (locale bundle)');
  }
}
