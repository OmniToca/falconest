import 'dart:convert';

import 'package:falconest/core/constants/app_languages.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// DTO řádku z tabulky tenant_message_templates.
///
/// PROČ: Jedna šablona = jeden kanál + globální předmět e-mailu + vícejazyčný obsah
/// v JSONB [translations]. Placeholdery v textech: {guest_name}, {flight_number}, …
class MessageTemplateRow {
  const MessageTemplateRow({
    required this.id,
    required this.tenantId,
    required this.key,
    required this.name,
    required this.channel,
    required this.translations,
    this.emailSubject,
    this.triggerContext,
    this.orderIndex = 0,
    this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String tenantId;
  final String key;
  final String name;
  final String channel;
  final String? emailSubject;
  final MessageTemplateTranslations translations;
  final String? triggerContext;
  final int orderIndex;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  factory MessageTemplateRow.fromJson(Map<String, dynamic> json) {
    final rawChannel = (json['channel'] as String?)?.trim();
    final normalizedChannel = _normalizeChannel(rawChannel);
    final rawOrder = json['order_index'];
    var orderIndex = 0;
    if (rawOrder != null) {
      if (rawOrder is int) {
        orderIndex = rawOrder;
      } else if (rawOrder is num) {
        orderIndex = rawOrder.toInt();
      }
    }
    return MessageTemplateRow(
      id: (json['id'] as String?) ?? '',
      tenantId: (json['tenant_id']?.toString() ?? '').trim(),
      key: (json['key']?.toString() ?? '').trim(),
      name: (json['name']?.toString() ?? '').trim(),
      channel: normalizedChannel,
      emailSubject: _normalizeNullableString(json['email_subject']),
      translations: MessageTemplateTranslations.tryParse(json['translations']) ??
          MessageTemplateTranslations.empty(),
      triggerContext:
          (json['trigger_context'] as String?)?.trim().isEmpty == true
              ? null
              : (json['trigger_context'] as String?)?.trim(),
      orderIndex: orderIndex,
      createdAt: _parseDateTime(json['created_at']),
      deletedAt: _parseDateTime(json['deleted_at']),
    );
  }

  /// Název pro výběrové seznamy (např. pravidlo automatizace): `name` z překladů v JSONB, jinak sloupec [name].
  ///
  /// PROČ: Uživatel má v jedné šabloně více jazyků; v dropdownu chceme čitelný popisek bez technického klíče.
  String get displayTitleForPicker {
    const order = ['cs', 'en', 'es'];
    for (final lang in order) {
      final n = translations.byLanguage[lang]?.name;
      if (n != null && n.trim().isNotEmpty) return n.trim();
    }
    for (final e in translations.byLanguage.values) {
      final n = e.name;
      if (n != null && n.trim().isNotEmpty) return n.trim();
    }
    return name;
  }

  /// Krátký náhled textu pro seznam šablon (první dostupný jazyk v preferovaném pořadí).
  String get previewSnippet {
    const order = ['cs', 'en', 'es'];
    for (final lang in order) {
      final b = translations.byLanguage[lang]?.body;
      if (b != null && b.trim().isNotEmpty) {
        final t = b.trim();
        return t.length > 100 ? '${t.substring(0, 100)}…' : t;
      }
    }
    for (final e in translations.byLanguage.values) {
      final b = e.body;
      if (b != null && b.trim().isNotEmpty) {
        final t = b.trim();
        return t.length > 100 ? '${t.substring(0, 100)}…' : t;
      }
    }
    return '';
  }

  /// Text zprávy pro hosta podle jazyka + rozumný fallback uvnitř [translations] (ne legacy sloupce).
  String resolvedBodyForGuest(String? guestLanguageCode) =>
      translations.resolvedBodyForGuest(guestLanguageCode);

  static String _normalizeChannel(String? rawChannel) {
    final c = (rawChannel ?? '').trim().toLowerCase();
    if (c == 'whatsapp_link') return 'whatsapp';
    if (c == 'sms' || c == 'email' || c == 'whatsapp' || c == 'internal_push') {
      return c;
    }
    return 'whatsapp';
  }

  static String? _normalizeNullableString(dynamic raw) {
    final v = raw?.toString().trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

/// Typovaný wrapper nad `tenant_message_templates.translations` (jsonb).
///
/// Očekávaný tvar:
/// {
///   "cs": {"body":"...", "subject":"...", "name":"..."},
///   "en": {"body":"..."}
/// }
class MessageTemplateTranslations {
  const MessageTemplateTranslations({required this.byLanguage});

  final Map<String, MessageTemplateTranslationEntry> byLanguage;

  /// Prázdná mapa – nové šablony nebo chybějící JSON v DB.
  static MessageTemplateTranslations empty() =>
      MessageTemplateTranslations(byLanguage: {});

  /// Parsování z Supabase jsonb (Map) nebo null.
  static MessageTemplateTranslations? tryParse(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;

    final out = <String, MessageTemplateTranslationEntry>{};
    for (final entry in raw.entries) {
      final languageCode = entry.key.toString().trim().toLowerCase();
      if (languageCode.isEmpty) continue;

      final value = entry.value;
      if (value is! Map) continue;
      final v = Map<String, dynamic>.from(value);
      out[languageCode] = MessageTemplateTranslationEntry(
        name: _nullableFromMap(v, 'name'),
        body: _nullableFromMap(v, 'body'),
        subject: _nullableFromMap(v, 'subject'),
      );
    }

    if (out.isEmpty) return null;
    return MessageTemplateTranslations(byLanguage: out);
  }

  /// Parsování z Drift / úložiště (JSON řetězec).
  static MessageTemplateTranslations parseFromStorage(String? json) {
    if (json == null || json.trim().isEmpty) return empty();
    try {
      final decoded = jsonDecode(json);
      return tryParse(decoded) ?? empty();
    } catch (e, st) {
      AppLogger.error('MessageTemplateTranslations.parseFromStorage: jsonDecode selhalo', e, st);
      return empty();
    }
  }

  /// Výběr textu pro hosta: preferovaný jazyk → en/cs/es → jakýkoliv neprázdný body.
  String resolvedBodyForGuest(String? guestLanguageCode) {
    final map = byLanguage;
    String? take(String? key) {
      if (key == null || key.isEmpty) return null;
      final b = map[key]?.body;
      if (b != null && b.trim().isNotEmpty) return b.trim();
      return null;
    }

    final g = guestLanguageCode?.trim().toLowerCase();
    if (g != null && g.isNotEmpty) {
      final d = take(g);
      if (d != null) return d;
    }
    // PROČ: Stejné pořadí jako katalog rezervací / editor šablon (včetně de, fr).
    for (final k in SupportedLanguages.all
        .where((a) => a.code != null)
        .map((a) => a.code!)) {
      final d = take(k);
      if (d != null) return d;
    }
    for (final e in map.values) {
      final b = e.body;
      if (b != null && b.trim().isNotEmpty) return b.trim();
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{};
    for (final e in byLanguage.entries) {
      out[e.key] = e.value.toJson();
    }
    return out;
  }

  static String? _nullableFromMap(Map<String, dynamic> map, String key) {
    final v = map[key]?.toString().trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }
}

class MessageTemplateTranslationEntry {
  const MessageTemplateTranslationEntry({
    this.name,
    this.body,
    this.subject,
  });

  final String? name;
  final String? body;
  final String? subject;

  Map<String, dynamic> toJson() {
    return {
      if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
      if (body != null && body!.trim().isNotEmpty) 'body': body!.trim(),
      if (subject != null && subject!.trim().isNotEmpty) 'subject': subject!.trim(),
    };
  }
}
