import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/models/automation/automation_enums.dart';
import 'package:falconest/core/theme/theme_ext.dart';
import 'package:falconest/core/widgets/sms_counter_text_field.dart';
import 'package:falconest/features/admin/providers/automation_queue_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';

/// Dialog pro ruční vložení zprávy do fronty automatizací (ad-hoc / test).
///
/// PROČ: Oddělený widget kvůli přehlednosti; stav držíme lokálně (setState).
/// SMS používá [SmsCounterInfo] jako šablony; WhatsApp je dostupný jen při aktivním
/// modulu [custom_twilio_whatsapp] (stejně jako u [AdminAutomationRuleFormDialog]).
class AdHocMessageDialog extends ConsumerStatefulWidget {
  const AdHocMessageDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AdHocMessageDialog(),
    );
  }

  @override
  ConsumerState<AdHocMessageDialog> createState() => _AdHocMessageDialogState();
}

class _AdHocMessageDialogState extends ConsumerState<AdHocMessageDialog> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  /// PROČ: Výchozí SMS – WhatsApp bez modulu by byl neplatný výběr (fronta by stejně selhala).
  AutomationChannel _channel = AutomationChannel.sms;
  bool _saving = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    final whatsappBlocked = !isModuleActive(ref, 'custom_twilio_whatsapp');
    if (_channel == AutomationChannel.whatsapp && whatsappBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('automation.rules.whatsapp_requires_custom_twilio'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(automationQueueProvider.notifier).insertAdhocMessage(
            channel: _channel,
            recipientContact: _recipientController.text,
            messageText: _bodyController.text,
            emailSubject: _channel == AutomationChannel.email
                ? _subjectController.text.trim()
                : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.queue_adhoc_success'.tr()),
          backgroundColor: context.customColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError && e.message == 'automation_queue.error_no_session'
          ? 'admin.queue_error_no_session'.tr()
          : 'common.generic_error_user_friendly'.tr();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: context.colors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final whatsappBlocked = !isModuleActive(ref, 'custom_twilio_whatsapp');
    final whatsappSegmentLabel = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('admin.rule_channel_whatsapp'.tr()),
        if (whatsappBlocked) ...[
          const SizedBox(width: 6),
          // PROČ: Zámeček přímo u nápisu kanálu je konzistentní s ostatními paywally v appce.
          Icon(Icons.lock_outline, size: 14, color: Theme.of(context).disabledColor),
        ],
      ],
    );

    return AlertDialog(
      title: Text('admin.queue_adhoc_title'.tr()),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'admin.queue_adhoc_channel'.tr(),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SegmentedButton<AutomationChannel>(
                  segments: [
                    ButtonSegment<AutomationChannel>(
                      value: AutomationChannel.sms,
                      label: Text('admin.rule_channel_sms'.tr()),
                      icon: const Icon(Icons.sms_outlined, size: 18),
                    ),
                    ButtonSegment<AutomationChannel>(
                      value: AutomationChannel.email,
                      label: Text('admin.rule_channel_email'.tr()),
                      icon: const Icon(Icons.email_outlined, size: 18),
                    ),
                    ButtonSegment<AutomationChannel>(
                      value: AutomationChannel.whatsapp,
                      enabled: !whatsappBlocked,
                      label: whatsappSegmentLabel,
                      icon: const Icon(Icons.chat, size: 18),
                      tooltip: whatsappBlocked
                          ? 'automation.rules.whatsapp_requires_custom_twilio'.tr()
                          : null,
                    ),
                  ],
                  selected: {_channel},
                  onSelectionChanged: (next) {
                    if (next.isEmpty) return;
                    if (next.first == AutomationChannel.whatsapp && whatsappBlocked) {
                      return;
                    }
                    setState(() => _channel = next.first);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _recipientController,
                  decoration: InputDecoration(
                    labelText: 'admin.queue_adhoc_recipient'.tr(),
                    hintText: 'admin.queue_adhoc_recipient_hint'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'admin.queue_adhoc_recipient_required'.tr();
                    }
                    return null;
                  },
                ),
                if (_channel == AutomationChannel.email) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _subjectController,
                    decoration: InputDecoration(
                      labelText: 'admin.queue_adhoc_subject'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'admin.queue_adhoc_subject_required'.tr();
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                if (_channel == AutomationChannel.sms)
                  FormField<String>(
                    validator: (_) {
                      if (_bodyController.text.trim().isEmpty) {
                        return 'admin.queue_adhoc_body_required'.tr();
                      }
                      return null;
                    },
                    builder: (fieldState) {
                      return SmsTextField(
                        controller: _bodyController,
                        decoration: InputDecoration(
                          labelText: 'admin.queue_adhoc_body'.tr(),
                          hintText: 'admin.queue_adhoc_body_hint'.tr(),
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                          errorText: fieldState.errorText,
                        ),
                        minLines: 4,
                        maxLines: 10,
                        keyboardType: TextInputType.multiline,
                        onChanged: (_) => fieldState.didChange(_bodyController.text),
                      );
                    },
                  )
                else
                  TextFormField(
                    controller: _bodyController,
                    decoration: InputDecoration(
                      labelText: 'admin.queue_adhoc_body'.tr(),
                      hintText: 'admin.queue_adhoc_body_hint'.tr(),
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    minLines: 4,
                    maxLines: 10,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'admin.queue_adhoc_body_required'.tr();
                      }
                      return null;
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _saving ? null : _onSave,
          child: _saving
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
