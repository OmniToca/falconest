import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Dialog výběru jazyka **jen pro export PDF** z podkladů fakturace.
///
/// **PROČ samostatný widget:** stejný krok potřebujeme v admin sekci Finance i v Klientské zóně (majitel),
/// aniž bychom duplikovali logiku dialogu. Excel export zůstává beze změny – dialog se volá pouze před PDF.
Future<Locale?> showBillingPdfExportLanguageDialog(BuildContext context) {
  final supported = context.supportedLocales;
  var selected = context.locale;

  return showDialog<Locale>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: Text('admin.finance.export_pdf_language_dialog_title'.tr()),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'admin.finance.export_pdf_language_dialog_subtitle'.tr(),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ...supported.map((locale) {
                    final labelKey = _pdfExportLanguageLabelKey(locale);
                    return RadioListTile<Locale>(
                      value: locale,
                      groupValue: selected,
                      title: Text(labelKey.tr()),
                      onChanged: (v) {
                        if (v != null) {
                          setSt(() => selected = v);
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(selected),
                child: Text('admin.finance.export_pdf_language_confirm'.tr()),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Mapuje [Locale] na klíč s lidským názvem jazyka v **aktuálním UI jazyku** (texty dialogu).
///
/// **PROČ:** v kódu nesmí být uživatelsky viditelné řetězce; názvy jazyků jsou v JSON (`export_pdf_language_option_*`).
String _pdfExportLanguageLabelKey(Locale locale) {
  switch (locale.languageCode) {
    case 'cs':
      return 'admin.finance.export_pdf_language_option_cs';
    case 'en':
      return 'admin.finance.export_pdf_language_option_en';
    case 'es':
      return 'admin.finance.export_pdf_language_option_es';
    default:
      return 'admin.finance.export_pdf_language_option_en';
  }
}
