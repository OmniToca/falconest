import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Dialog pro manuální zadání překladů názvu (služba → `name_i18n`, úkol → `title_i18n`) pro PDF a exporty.
///
/// **PROČ samostatný dialog:** Stejný tvar JSON (`translations` + volitelně `source_hash`) používáme
/// u katalogu i u řádku úkolu; dispečer tak zadává CS/EN/ES na jednom místě. Hodnota u úkolu se při
/// uložení zaznamená přímo do řádku (snapshot) — budoucí změna ceníku nepřepíše historické reporty.
class ExportI18nEditorDialog extends StatefulWidget {
  const ExportI18nEditorDialog._({this.initial});

  /// Vstupní mapa ve tvaru PostgREST (`name_i18n` / `title_i18n`), může být null.
  final Map<String, dynamic>? initial;

  /// Zobrazí dialog a vrátí upravenou mapu po Potvrdit, nebo `null` při zrušení.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    Map<String, dynamic>? initial,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => ExportI18nEditorDialog._(initial: initial),
    );
  }

  @override
  State<ExportI18nEditorDialog> createState() => _ExportI18nEditorDialogState();
}

class _ExportI18nEditorDialogState extends State<ExportI18nEditorDialog> {
  late final TextEditingController _cs;
  late final TextEditingController _en;
  late final TextEditingController _es;

  static String _readLang(Map<String, dynamic>? root, String lang) {
    if (root == null) return '';
    final tr = root['translations'];
    if (tr is! Map) return '';
    final v = tr[lang] ?? tr[lang.toUpperCase()];
    return v?.toString().trim() ?? '';
  }

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _cs = TextEditingController(text: _readLang(i, 'cs'));
    _en = TextEditingController(text: _readLang(i, 'en'));
    _es = TextEditingController(text: _readLang(i, 'es'));
  }

  @override
  void dispose() {
    _cs.dispose();
    _en.dispose();
    _es.dispose();
    super.dispose();
  }

  /// Sestaví payload pro DB: jen neprázdné jazyky; zachová `source_hash` z původního JSON, pokud existuje.
  Map<String, dynamic> _buildResult() {
    final translations = <String, String>{};
    final cs = _cs.text.trim();
    final en = _en.text.trim();
    final es = _es.text.trim();
    if (cs.isNotEmpty) translations['cs'] = cs;
    if (en.isNotEmpty) translations['en'] = en;
    if (es.isNotEmpty) translations['es'] = es;

    final out = <String, dynamic>{};
    if (translations.isNotEmpty) {
      out['translations'] = translations;
    }
    final hashRaw = widget.initial?['source_hash'];
    if (hashRaw != null) {
      final h = hashRaw.toString().trim();
      if (h.isNotEmpty) {
        out['source_hash'] = h;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('export_i18n.dialog_title'.tr()),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'export_i18n.dialog_subtitle'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cs,
                decoration: InputDecoration(
                  labelText: 'export_i18n.field_cs'.tr(),
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _en,
                decoration: InputDecoration(
                  labelText: 'export_i18n.field_en'.tr(),
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _es,
                decoration: InputDecoration(
                  labelText: 'export_i18n.field_es'.tr(),
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_buildResult()),
          child: Text('common.confirm'.tr()),
        ),
      ],
    );
  }
}
