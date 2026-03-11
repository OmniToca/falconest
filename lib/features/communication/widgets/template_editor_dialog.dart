import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/features/communication/models/message_template_row.dart';
import 'package:falconest/features/communication/providers/message_templates_admin_provider.dart';
import 'package:falconest/features/communication/services/template_placeholder_service.dart';
import 'package:falconest/features/communication/utils/communication_error_helper.dart';

/// Možnosti trigger kontextu – kdy se šablona zobrazí řidiči.
const _triggerOptions = [
  ('general', 'communication.template_trigger_general'),
  ('transfer', 'communication.template_trigger_transfer'),
  ('check_in', 'communication.template_trigger_check_in'),
  ('check_out', 'communication.template_trigger_check_out'),
];

/// Možnosti jazyka hosta – NULL = výchozí pro všechny.
const _languageOptions = [
  (null, 'communication.template_language_default'),
  ('cs', 'communication.template_language_cs'),
  ('en', 'communication.template_language_en'),
  ('es', 'communication.template_language_es'),
  ('de', 'communication.template_language_de'),
  ('fr', 'communication.template_language_fr'),
];

/// Mapování placeholder klíčů na i18n popisky.
const _placeholderLabels = {
  'guest_name': 'communication.placeholder_guest_name',
  'guest_phone': 'communication.placeholder_guest_phone',
  'flight_number': 'communication.placeholder_flight_number',
  'address': 'communication.placeholder_address',
  'keybox': 'communication.placeholder_keybox',
  'reference_number': 'communication.placeholder_reference_number',
  'apartment_name': 'communication.placeholder_apartment_name',
  'owner_notes': 'communication.placeholder_owner_notes',
};

/// Dialog pro přidání nebo úpravu šablony zprávy.
///
/// PROČ: Agentura vytváří texty s placeholdery ({guest_name}, {flight_number}…),
/// které mobilní aplikace nahradí daty z úkolu. Klikatelné chipsy pod polem
/// usnadňují vložení proměnné bez nutnosti pamatovat si přesnou syntaxi.
class TemplateEditorDialog extends ConsumerStatefulWidget {
  const TemplateEditorDialog({
    super.key,
    required this.ref,
    this.template,
    required this.onSaved,
  });

  final WidgetRef ref;
  /// Null = nová šablona, jinak úprava existující.
  final MessageTemplateRow? template;
  final VoidCallback onSaved;

  @override
  ConsumerState<TemplateEditorDialog> createState() =>
      _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends ConsumerState<TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bodyController;
  String _triggerContext = 'general';
  String? _languageCode;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameController = TextEditingController(text: t?.name ?? '');
    _bodyController = TextEditingController(text: t?.body ?? '');
    _triggerContext = t?.triggerContext?.trim().isNotEmpty == true
        ? t!.triggerContext!
        : 'general';
    _languageCode = t?.languageCode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _insertPlaceholder(String key) {
    final placeholder = '{$key}';
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.baseOffset;
    final end = selection.extentOffset;
    final newText = start <= end
        ? '${text.substring(0, start)}$placeholder${text.substring(end)}'
        : '${text.substring(0, end)}$placeholder${text.substring(start)}';
    _bodyController.text = newText;
    _bodyController.selection = TextSelection.collapsed(offset: start + placeholder.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.template != null;
    final notifier = ref.watch(messageTemplatesAdminNotifierProvider.notifier);
    final asyncState = ref.watch(messageTemplatesAdminNotifierProvider);

    return AlertDialog(
      title: Text(isEdit ? 'communication.edit_template'.tr() : 'communication.add_template'.tr()),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                DropdownButtonFormField<String>(
                  initialValue: _triggerContext,
                  decoration: InputDecoration(
                    labelText: 'communication.template_trigger'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: _triggerOptions
                      .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2.tr())))
                      .toList(),
                  onChanged: (v) => setState(() => _triggerContext = v ?? 'general'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _languageCode,
                  decoration: InputDecoration(
                    labelText: 'communication.template_language'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  items: _languageOptions.map((e) {
                    return DropdownMenuItem<String?>(
                      value: e.$1,
                      child: Text(e.$2.tr()),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _languageCode = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  decoration: InputDecoration(
                    labelText: 'communication.template_body'.tr(),
                    hintText: 'communication.template_body_hint'.tr(),
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  minLines: 3,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'communication.validation_body_required'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'communication.available_placeholders'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TemplatePlaceholderService.supportedPlaceholders
                      .map((key) {
                    final labelKey = _placeholderLabels[key] ?? key;
                    return ActionChip(
                      label: Text('{$key}'),
                      onPressed: () => _insertPlaceholder(key),
                      tooltip: labelKey.tr(),
                    );
                  })
                      .toList(),
                ),
                if (asyncState.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    'communication.save_error'.tr(
                      namedArgs: {'error': userFacingCommunicationError(asyncState.error)},
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
                  final name = _nameController.text.trim();
                  final body = _bodyController.text.trim();
                  if (isEdit) {
                    final t = widget.template!;
                    await notifier.update(
                      MessageTemplateRow(
                        id: t.id,
                        tenantId: t.tenantId,
                        key: t.key,
                        name: name,
                        body: body,
                        channel: t.channel,
                        triggerContext: _triggerContext == 'general' ? null : _triggerContext,
                        languageCode: _languageCode,
                        orderIndex: t.orderIndex,
                        createdAt: t.createdAt,
                        deletedAt: t.deletedAt,
                      ),
                    );
                  } else {
                    await notifier.create(
                      name: name,
                      body: body,
                      triggerContext: _triggerContext == 'general' ? null : _triggerContext,
                      languageCode: _languageCode,
                    );
                  }
                  if (!mounted) return;
                  final hasError = ref.read(messageTemplatesAdminNotifierProvider).hasError;
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
