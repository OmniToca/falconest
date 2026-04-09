import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/constants/app_languages.dart';
import 'package:falconest/features/admin/providers/task_categories_provider.dart';
import 'package:falconest/features/communication/models/message_template_row.dart';
import 'package:falconest/features/communication/providers/message_templates_admin_provider.dart';
import 'package:falconest/features/communication/services/template_placeholder_service.dart';
import 'package:falconest/features/communication/utils/communication_error_helper.dart';
import 'package:falconest/core/widgets/sms_counter_text_field.dart';

/// Mapování placeholder klíčů na i18n popisky.
const _placeholderLabels = {
  'guest_name': 'communication.placeholder_guest_name',
  'guest_phone': 'communication.placeholder_guest_phone',
  'flight_number': 'communication.placeholder_flight_number',
  'address': 'communication.placeholder_address',
  'keybox': 'communication.placeholder_keybox',
  'parking': 'communication.placeholder_parking',
  'review_link': 'communication.placeholder_review_link',
  'reference_number': 'communication.placeholder_reference_number',
  'apartment_name': 'communication.placeholder_apartment_name',
  'owner_notes': 'communication.placeholder_owner_notes',
  'task_date': 'communication.placeholder_task_date',
  'task_time': 'communication.placeholder_task_time',
  'arrival_date': 'communication.placeholder_arrival_date',
  'arrival_time': 'communication.placeholder_arrival_time',
  'departure_date': 'communication.placeholder_departure_date',
  'departure_time': 'communication.placeholder_departure_time',
};

/// Kódy jazyků z [SupportedLanguages] (bez „výchozí“), stabilní pořadí pro řazení UI.
List<String> _catalogLanguageCodes() {
  return SupportedLanguages.all
      .where((a) => a.code != null)
      .map((a) => a.code!)
      .toList();
}

/// PROČ: Jednotné řazení panelů podle katalogu; neznámé kódy (legacy) přidáme na konec.
List<String> _orderedLangKeys(Iterable<String> keys) {
  final set = keys.map((e) => e.toLowerCase()).toSet();
  final order = _catalogLanguageCodes();
  final out = <String>[];
  for (final o in order) {
    if (set.contains(o)) out.add(o);
  }
  for (final x in set) {
    if (!out.contains(x)) out.add(x);
  }
  return out;
}

String? _labelKeyForLangCode(String code) {
  final c = code.trim().toLowerCase();
  for (final a in SupportedLanguages.all) {
    if (a.code == c) return a.labelKey;
  }
  return null;
}

/// Dialog pro přidání nebo úpravu šablony zprávy (kanál, dynamické jazyky v JSONB `translations`).
///
/// PROČ: Lokální [setState] – nepřetěžujeme Riverpod při každém znaku. Seznam aktivních
/// jazyků je řízen polem [_activeLangCodes]; pro každý jazyk držíme [TextEditingController]
/// v mapách [_bodyByLang] a [_subjectByLang] (předmět jen u e-mailu).
class TemplateEditorDialog extends ConsumerStatefulWidget {
  const TemplateEditorDialog({
    super.key,
    this.template,
    required this.onSaved,
  });

  final MessageTemplateRow? template;
  final VoidCallback onSaved;

  @override
  ConsumerState<TemplateEditorDialog> createState() =>
      _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends ConsumerState<TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  /// Aktivní jazyky překladu (ISO kódy), pořadí podle [_orderedLangKeys].
  late List<String> _activeLangCodes;

  final Map<String, TextEditingController> _bodyByLang = {};
  final Map<String, TextEditingController> _subjectByLang = {};

  /// sms | email | whatsapp | internal_push – odpovídá DB CHECK constraintu.
  late String _channel;
  /// Null = obecná šablona; jinak kód z task_categories.
  String? _triggerContext;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameController = TextEditingController(text: t?.name ?? '');
    final tr = t?.translations ?? MessageTemplateTranslations.empty();

    if (tr.byLanguage.isEmpty) {
      // PROČ: Výchozí tři jazyky jako start – manažer může odebrat / doplnit dle katalogu.
      _activeLangCodes = ['cs', 'en', 'es'];
    } else {
      _activeLangCodes = _orderedLangKeys(tr.byLanguage.keys);
    }

    _channel = (t?.channel ?? 'whatsapp').trim().toLowerCase();
    if (_channel != 'sms' &&
        _channel != 'email' &&
        _channel != 'whatsapp' &&
        _channel != 'internal_push') {
      _channel = 'whatsapp';
    }
    final raw = t?.triggerContext?.trim();
    _triggerContext = (raw != null && raw.isNotEmpty && raw != 'general')
        ? raw
        : null;

    for (final lang in _activeLangCodes) {
      final entry = tr.byLanguage[lang];
      _attachControllersForLang(lang, entry);
    }

    _seedEmailSubjectsFromRoot(t, tr);
  }

  /// PROČ: Sloupec `email_subject` v DB je jeden – pro kompatibilitu vyplníme chybějící
  /// per-jazykové předměty z kořenové hodnoty při editaci starých šablon.
  void _seedEmailSubjectsFromRoot(MessageTemplateRow? t, MessageTemplateTranslations tr) {
    if (_channel != 'email' || t == null) return;
    final root = t.emailSubject?.trim();
    if (root == null || root.isEmpty) return;
    for (final lang in _activeLangCodes) {
      final has = tr.byLanguage[lang]?.subject?.trim().isNotEmpty == true;
      if (!has) {
        _subjectByLang[lang]?.text = root;
      }
    }
  }

  void _attachControllersForLang(String lang, MessageTemplateTranslationEntry? entry) {
    final bodyCtrl = TextEditingController(text: entry?.body ?? '');
    bodyCtrl.addListener(_onFieldsChanged);
    _bodyByLang[lang] = bodyCtrl;

    final subCtrl = TextEditingController(text: entry?.subject ?? '');
    subCtrl.addListener(_onFieldsChanged);
    _subjectByLang[lang] = subCtrl;
  }

  void _onFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _bodyByLang.values) {
      c.removeListener(_onFieldsChanged);
      c.dispose();
    }
    for (final c in _subjectByLang.values) {
      c.removeListener(_onFieldsChanged);
      c.dispose();
    }
    super.dispose();
  }

  void _insertPlaceholder(String lang, String key) {
    final placeholder = '{$key}';
    final controller = _bodyByLang[lang];
    if (controller == null) return;
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.baseOffset;
    final end = selection.extentOffset;
    final newText = start <= end
        ? '${text.substring(0, start)}$placeholder${text.substring(end)}'
        : '${text.substring(0, end)}$placeholder${text.substring(start)}';
    controller.text = newText;
    controller.selection =
        TextSelection.collapsed(offset: start + placeholder.length);
    setState(() {});
  }

  MessageTemplateTranslations _buildTranslations() {
    final m = <String, MessageTemplateTranslationEntry>{};
    for (final lang in _activeLangCodes) {
      final body = _bodyByLang[lang]?.text.trim() ?? '';
      final sub = _channel == 'email'
          ? (_subjectByLang[lang]?.text.trim() ?? '')
          : '';
      if (body.isNotEmpty || sub.isNotEmpty) {
        m[lang] = MessageTemplateTranslationEntry(
          body: body.isNotEmpty ? body : null,
          subject: sub.isNotEmpty ? sub : null,
        );
      }
    }
    return MessageTemplateTranslations(byLanguage: m);
  }

  /// PROČ: Kořenový sloupec `email_subject` v DB – vezmeme první neprázdný předmět
  /// v pořadí katalogu jazyků.
  String? _deriveRootEmailSubject(MessageTemplateTranslations tr) {
    for (final code in _catalogLanguageCodes()) {
      final s = tr.byLanguage[code]?.subject;
      if (s != null && s.trim().isNotEmpty) return s.trim();
    }
    for (final e in tr.byLanguage.values) {
      final s = e.subject;
      if (s != null && s.trim().isNotEmpty) return s.trim();
    }
    return null;
  }

  bool _validateTranslations() {
    final tr = _buildTranslations();
    if (tr.byLanguage.isEmpty ||
        !tr.byLanguage.values.any((e) => e.body != null && e.body!.trim().isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('communication.validation_translations_required'.tr()),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return false;
    }
    return true;
  }

  String _longestSmsBodyPreview() {
    var max = '';
    for (final lang in _activeLangCodes) {
      final t = _bodyByLang[lang]?.text ?? '';
      if (t.length > max.length) max = t;
    }
    return max;
  }

  Future<void> _showAddLanguageDialog() async {
    final catalog = _catalogLanguageCodes();
    final available =
        catalog.where((c) => !_activeLangCodes.contains(c)).toList();
    if (available.isEmpty) return;

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('communication.template_pick_language_title'.tr()),
        content: SizedBox(
          width: 320,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: available.length,
            itemBuilder: (_, i) {
              final code = available[i];
              final lk = _labelKeyForLangCode(code);
              return ListTile(
                title: Text(lk != null ? lk.tr() : code.toUpperCase()),
                onTap: () => Navigator.of(ctx).pop(code),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );

    if (picked == null || !mounted) return;
    _attachControllersForLang(picked, null);
    setState(() {
      _activeLangCodes = _orderedLangKeys([..._activeLangCodes, picked]);
    });
  }

  void _removeLanguage(String code) {
    if (_activeLangCodes.length <= 1) return;
    setState(() {
      _activeLangCodes.removeWhere((e) => e == code);
      _bodyByLang[code]?.removeListener(_onFieldsChanged);
      _subjectByLang[code]?.removeListener(_onFieldsChanged);
      _bodyByLang[code]?.dispose();
      _subjectByLang[code]?.dispose();
      _bodyByLang.remove(code);
      _subjectByLang.remove(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.template != null;
    final notifier = ref.watch(messageTemplatesAdminNotifierProvider.notifier);
    final asyncState = ref.watch(messageTemplatesAdminNotifierProvider);

    final catalog = _catalogLanguageCodes();
    final canAddLanguage =
        catalog.any((c) => !_activeLangCodes.contains(c));

    return AlertDialog(
      title: Text(isEdit ? 'communication.edit_template'.tr() : 'communication.add_template'.tr()),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'communication.template_channel'.tr(),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                // PROČ: Kanál WhatsApp u šablon **nikdy** neomezujeme – šablony slouží i pro manuální
                // otevření odkazu wa.me v prohlížeči/telefonu (bez Twilio API), na rozdíl od automatizací.
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(
                      value: 'sms',
                      label: Text('communication.channel_sms'.tr()),
                      icon: const Icon(Icons.sms_outlined, size: 18),
                    ),
                    ButtonSegment<String>(
                      value: 'email',
                      label: Text('communication.channel_email'.tr()),
                      icon: const Icon(Icons.email_outlined, size: 18),
                    ),
                    ButtonSegment<String>(
                      value: 'whatsapp',
                      label: Text('communication.channel_whatsapp'.tr()),
                      icon: const Icon(Icons.chat, size: 18),
                    ),
                    ButtonSegment<String>(
                      value: 'internal_push',
                      label: Text('communication.channel_internal_push'.tr()),
                      icon: const Icon(Icons.notifications_active_outlined, size: 18),
                    ),
                  ],
                  selected: {_channel},
                  onSelectionChanged: (next) {
                    setState(() => _channel = next.first);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'communication.template_name'.tr(),
                    hintText: 'communication.template_name_hint'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'communication.validation_name_required'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _TriggerContextDropdown(
                  value: _triggerContext,
                  onChanged: (v) => setState(() => _triggerContext = v),
                ),
                const SizedBox(height: 16),
                Text(
                  'communication.template_language_tabs'.tr(),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: canAddLanguage ? _showAddLanguageDialog : null,
                    icon: const Icon(Icons.add, size: 20),
                    label: Text('communication.template_add_language'.tr()),
                  ),
                ),
                const SizedBox(height: 8),
                ..._activeLangCodes.map((lang) {
                  final labelKey = _labelKeyForLangCode(lang);
                  final title = labelKey != null ? labelKey.tr() : lang.toUpperCase();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      initiallyExpanded: lang == _activeLangCodes.first,
                      title: Row(
                        children: [
                          Expanded(child: Text(title)),
                          if (_activeLangCodes.length > 1)
                            IconButton(
                              tooltip: 'communication.template_remove_language_tooltip'.tr(),
                              icon: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () => _removeLanguage(lang),
                            ),
                        ],
                      ),
                      children: [
                        if (_channel == 'email') ...[
                          TextFormField(
                            controller: _subjectByLang[lang],
                            decoration: InputDecoration(
                              labelText: 'communication.template_email_subject'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _bodyByLang[lang],
                          decoration: InputDecoration(
                            labelText: 'communication.template_body'.tr(),
                            hintText: 'communication.template_body_hint'.tr(),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 8,
                          minLines: 5,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'communication.available_placeholders'.tr(),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: TemplatePlaceholderService.supportedPlaceholders
                              .map((key) {
                            final labelKeyPh = _placeholderLabels[key] ?? key;
                            return ActionChip(
                              label: Text('{$key}'),
                              onPressed: () => _insertPlaceholder(lang, key),
                              tooltip: labelKeyPh.tr(),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }),
                if (_channel == 'sms')
                  SmsCounterInfo(text: _longestSmsBodyPreview()),
                const SizedBox(height: 12),
                if (asyncState.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    'communication.save_error'.tr(
                      namedArgs: {
                        'error': userFacingCommunicationError(asyncState.error),
                      },
                    ),
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: asyncState.isLoading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  if (!_validateTranslations()) return;
                  final name = _nameController.text.trim();
                  final translations = _buildTranslations();
                  final emailSub = _channel == 'email'
                      ? _deriveRootEmailSubject(translations)
                      : null;
                  if (isEdit) {
                    final t = widget.template!;
                    await notifier.update(
                      MessageTemplateRow(
                        id: t.id,
                        tenantId: t.tenantId,
                        key: t.key,
                        name: name,
                        channel: _channel,
                        emailSubject:
                            emailSub != null && emailSub.isNotEmpty ? emailSub : null,
                        translations: translations,
                        triggerContext:
                            _triggerContext?.trim().isEmpty == true ? null : _triggerContext,
                        orderIndex: t.orderIndex,
                        createdAt: t.createdAt,
                        deletedAt: t.deletedAt,
                      ),
                    );
                  } else {
                    await notifier.create(
                      name: name,
                      channel: _channel,
                      emailSubject:
                          emailSub != null && emailSub.isNotEmpty ? emailSub : null,
                      translations: translations,
                      triggerContext:
                          _triggerContext?.trim().isEmpty == true ? null : _triggerContext,
                    );
                  }
                  if (!mounted) return;
                  final hasError =
                      ref.read(messageTemplatesAdminNotifierProvider).hasError;
                  if (hasError) return;
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  widget.onSaved();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('communication.saved'.tr()),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
          child: asyncState.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }
}

/// Dynamický dropdown pro výběr kontextu spuštění šablony (kategorie úkolu z task_categories).
class _TriggerContextDropdown extends ConsumerWidget {
  const _TriggerContextDropdown({
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(taskCategoriesProvider);
    return categoriesAsync.when(
      data: (categoriesByCode) {
        final sorted = categoriesByCode.values.toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        return DropdownButtonFormField<String?>(
          initialValue: value,
          decoration: InputDecoration(
            labelText: 'communication.template_trigger'.tr(),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('communication.template_trigger_general'.tr()),
            ),
            ...sorted.map((c) => DropdownMenuItem<String?>(
                  value: c.code,
                  child: Text('admin.task_type_${c.code}'.tr()),
                )),
          ],
          onChanged: onChanged,
        );
      },
      loading: () => DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: 'communication.template_trigger'.tr(),
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('communication.template_trigger_general'.tr()),
          ),
        ],
        onChanged: null,
      ),
      error: (Object? err, StackTrace? stackTrace) => DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: 'communication.template_trigger'.tr(),
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('communication.template_trigger_general'.tr()),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
