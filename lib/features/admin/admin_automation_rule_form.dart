import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/automation/automation_enums.dart';
import 'package:falconest/core/models/automation/automation_rule_row.dart';
import 'package:falconest/features/communication/models/message_template_row.dart';
import 'package:falconest/features/communication/providers/message_templates_admin_provider.dart';
import 'package:falconest/features/admin/providers/automation_rules_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/settings/providers/tenant_integration_settings_provider.dart';

/// Dialog pro vytvoření nebo úpravu pravidla automatizace (FÁZE 3).
///
/// PROČ: Jeden formulář pro INSERT i UPDATE šetří duplicitu UI; při [ruleToEdit]
/// jen předvyplníme stav a při uložení voláme buď [createRule], nebo [updateRule].
class AdminAutomationRuleFormDialog extends ConsumerStatefulWidget {
  const AdminAutomationRuleFormDialog({super.key, this.ruleToEdit});

  /// Volitelné pravidlo k úpravě; `null` = nové pravidlo (INSERT).
  final AutomationRuleRow? ruleToEdit;

  static Future<void> show(BuildContext context, {AutomationRuleRow? ruleToEdit}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminAutomationRuleFormDialog(ruleToEdit: ruleToEdit),
    );
  }

  @override
  ConsumerState<AdminAutomationRuleFormDialog> createState() => _AdminAutomationRuleFormDialogState();
}

enum _OffsetUnitUi {
  hours,
  days,
}

enum _OffsetDirectionUi {
  before,
  after,
}

class _AdminAutomationRuleFormDialogState extends ConsumerState<AdminAutomationRuleFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _offsetController = TextEditingController();

  // Trigger událost (DB string)
  String _triggerEvent = 'reservation_check_in';

  // Offset
  _OffsetUnitUi _offsetUnit = _OffsetUnitUi.days;
  _OffsetDirectionUi _offsetDirection = _OffsetDirectionUi.before;

  // Channel
  AutomationChannel _channel = AutomationChannel.whatsapp;

  // Template
  String? _selectedTemplateId;

  // Quiet hours
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 8, minute: 0);

  bool _saving = false;

  /// PROČ: U kanálu [AutomationChannel.internalPush] ukládáme [profiles.id] příjemce FCM.
  String? _staffProfileId;

  /// PROČ: Při novém pravidle je výchozí kanál WhatsApp; pokud agentura nemá vlastní Twilio,
  /// jednorázově přepneme na SMS až po načtení [tenantIntegrationSettingsProvider], aby nezůstala
  /// neplatná kombinace.
  bool _didAutoFixChannelForNewRuleWithoutTwilio = false;

  /// Známe hodnoty triggeru z UI; ostatní z DB zobrazíme jako extra položku dropdownu.
  static const Set<String> _knownTriggerEvents = {
    'reservation_check_in',
    'reservation_check_out',
    'task_start',
  };

  @override
  void initState() {
    super.initState();
    final r = widget.ruleToEdit;
    if (r == null) return;

    _nameController.text = r.name;
    _triggerEvent = r.triggerEvent.trim().isEmpty ? 'reservation_check_in' : r.triggerEvent.trim();
    _channel = r.channel;
    final sp = r.staffProfileId?.trim();
    _staffProfileId = (sp == null || sp.isEmpty) ? null : sp;
    _selectedTemplateId = r.templateId.trim().isEmpty ? null : r.templateId.trim();
    _applyOffsetFromMinutes(r.offsetMinutes);
    final qs = _parseTimeOfDayFromDb(r.quietHoursStart);
    final qe = _parseTimeOfDayFromDb(r.quietHoursEnd);
    if (qs != null) _quietStart = qs;
    if (qe != null) _quietEnd = qe;
  }

  /// Převede `offset_minutes` z DB na pole jednotek/směru a číslo ve formuláři.
  ///
  /// PROČ: DB ukládá signed minuty; UI pracuje s kladnou hodnotou + směrem před/po.
  void _applyOffsetFromMinutes(int offsetMinutes) {
    final abs = offsetMinutes.abs();
    _offsetDirection = offsetMinutes < 0 ? _OffsetDirectionUi.before : _OffsetDirectionUi.after;

    if (abs == 0) {
      _offsetUnit = _OffsetUnitUi.hours;
      _offsetController.text = '0';
      return;
    }

    if (abs % (24 * 60) == 0) {
      _offsetUnit = _OffsetUnitUi.days;
      _offsetController.text = (abs ~/ (24 * 60)).toString();
      return;
    }

    if (abs % 60 == 0) {
      _offsetUnit = _OffsetUnitUi.hours;
      _offsetController.text = (abs ~/ 60).toString();
      return;
    }

    _offsetUnit = _OffsetUnitUi.hours;
    _offsetController.text = ((abs + 59) ~/ 60).toString();
  }

  /// Parsuje Postgres `time` (`HH:MM` nebo `HH:MM:SS`) do [TimeOfDay].
  TimeOfDay? _parseTimeOfDayFromDb(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _offsetController.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay t) {
    // DB pole typu `time` očekává HH:MM:SS; ukládáme přesně na sekundách.
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  int _computeOffsetMinutes() {
    final raw = _offsetController.text.trim();
    final value = int.tryParse(raw);
    final safeValue = value ?? 0;

    final baseMinutes = switch (_offsetUnit) {
      _OffsetUnitUi.hours => safeValue * 60,
      _OffsetUnitUi.days => safeValue * 24 * 60,
    };
    final sign = switch (_offsetDirection) {
      _OffsetDirectionUi.before => -1,
      _OffsetDirectionUi.after => 1,
    };
    return baseMinutes * sign;
  }

  /// Šablony pro aktuální kanál pravidla (DB už filtruje deleted_at přes provider).
  List<MessageTemplateRow> _templatesForSelectedChannel(List<MessageTemplateRow> all) {
    final ch = _channel.toDb();
    return all.where((t) => t.channel.trim().toLowerCase() == ch).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  void _onChannelChanged(AutomationChannel next) {
    setState(() {
      _channel = next;
      // PROČ: Šablona je vždy vázaná na jeden kanál – změna kanálu zneplatní předchozí výběr.
      _selectedTemplateId = null;
      if (next != AutomationChannel.internalPush) {
        _staffProfileId = null;
      }
    });
  }

  Future<void> _pickQuietStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _quietStart,
    );
    if (picked == null) return;
    setState(() => _quietStart = picked);
  }

  Future<void> _pickQuietEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _quietEnd,
    );
    if (picked == null) return;
    setState(() => _quietEnd = picked);
  }

  /// PROČ: Stejná logika jako Edge `sendViaTwilioWhatsApp` – oba údaje musí být v JSONB.
  bool _hasCustomTwilioFromMap(Map<String, dynamic> map) {
    final sid = map[kTenantIntegrationTwilioAccountSid]?.toString().trim() ?? '';
    final token = map[kTenantIntegrationTwilioAuthToken]?.toString().trim() ?? '';
    return sid.isNotEmpty && token.isNotEmpty;
  }

  Future<void> _onSave() async {
    final valid = _formKey.currentState?.validate() == true;
    if (!valid) return;
    if (_saving) return;

    // PROČ: Automatický WhatsApp přes Twilio API vyžaduje vlastní účet – bez něj pravidlo neuložíme.
    final tenantIdForSave = ref.read(authNotifierProvider).tenantIdForData;
    Map<String, dynamic> integrationMap = {};
    if (tenantIdForSave != null && tenantIdForSave.isNotEmpty) {
      final av = ref.read(tenantIntegrationSettingsProvider(tenantIdForSave));
      integrationMap = av.valueOrNull ?? {};
    }
    if (_channel == AutomationChannel.whatsapp &&
        !_hasCustomTwilioFromMap(integrationMap)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('automation.rules.whatsapp_requires_custom_twilio'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    if (_selectedTemplateId == null || _selectedTemplateId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.rule_validation_template_required'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) setState(() => _saving = false);
      return;
    }

    try {
      final now = DateTime.now().toUtc();
      final edit = widget.ruleToEdit;

      if (edit == null) {
        final rule = AutomationRuleRow(
          id: '',
          tenantId: '',
          name: _nameController.text.trim(),
          isActive: true,
          triggerEvent: _triggerEvent,
          offsetMinutes: _computeOffsetMinutes(),
          channel: _channel,
          templateId: _selectedTemplateId ?? '',
          targetEntity: _channel == AutomationChannel.internalPush ? 'staff' : 'guest',
          staffProfileId: _channel == AutomationChannel.internalPush ? _staffProfileId : null,
          quietHoursStart: _formatTimeOfDay(_quietStart),
          quietHoursEnd: _formatTimeOfDay(_quietEnd),
          createdAt: now,
          updatedAt: now,
        );

        await ref.read(automationRulesProvider.notifier).createRule(rule);
      } else {
        final updated = edit.copyWith(
          name: _nameController.text.trim(),
          triggerEvent: _triggerEvent,
          offsetMinutes: _computeOffsetMinutes(),
          channel: _channel,
          templateId: _selectedTemplateId ?? '',
          targetEntity: _channel == AutomationChannel.internalPush
              ? 'staff'
              : (edit.targetEntity.trim().isEmpty ? 'guest' : edit.targetEntity.trim()),
          clearStaffProfileId: _channel != AutomationChannel.internalPush,
          staffProfileId: _channel == AutomationChannel.internalPush ? _staffProfileId : null,
          quietHoursStart: _formatTimeOfDay(_quietStart),
          quietHoursEnd: _formatTimeOfDay(_quietEnd),
          updatedAt: now,
        );

        await ref.read(automationRulesProvider.notifier).updateRule(updated);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
    final integrationAsync = (tenantId != null && tenantId.isNotEmpty)
        ? ref.watch(tenantIntegrationSettingsProvider(tenantId))
        : null;
    final integrationMap = integrationAsync?.valueOrNull ?? <String, dynamic>{};
    final hasCustomTwilio = _hasCustomTwilioFromMap(integrationMap);
    final whatsappBlocked = !hasCustomTwilio;

    // PROČ: Nové pravidlo nesmí zůstat na WhatsAppu bez Twilio – přepneme na SMS po načtení integrací.
    if (!_didAutoFixChannelForNewRuleWithoutTwilio &&
        widget.ruleToEdit == null &&
        whatsappBlocked &&
        _channel == AutomationChannel.whatsapp &&
        (integrationAsync?.hasValue ?? false)) {
      _didAutoFixChannelForNewRuleWithoutTwilio = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _channel = AutomationChannel.sms);
        }
      });
    }

    final templatesAsync = ref.watch(messageTemplatesAdminProvider);
    final allTemplates = templatesAsync.valueOrNull ?? const <MessageTemplateRow>[];
    final filteredTemplates = _templatesForSelectedChannel(allTemplates);
    final sel = _selectedTemplateId?.trim();
    final selectionInFiltered = sel != null &&
        sel.isNotEmpty &&
        filteredTemplates.any((t) => t.id == sel);
    final whatsappRuleInvalid =
        _channel == AutomationChannel.whatsapp && whatsappBlocked;
    final internalPushOk = _channel != AutomationChannel.internalPush ||
        (_staffProfileId != null && _staffProfileId!.trim().isNotEmpty);
    final canSave = !_saving &&
        internalPushOk &&
        sel != null &&
        sel.isNotEmpty &&
        selectionInFiltered &&
        templatesAsync.valueOrNull?.isNotEmpty == true &&
        !whatsappRuleInvalid;

    final isEdit = widget.ruleToEdit != null;

    return AlertDialog(
      title: Text(isEdit ? 'admin.rule_edit_title'.tr() : 'admin.rule_form_title'.tr()),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Krok 1: kanál první – řídí filtrování šablon a při změně resetuje výběr šablony.
                Text(
                  'admin.rule_channel'.tr(),
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
                      label: Text('admin.rule_channel_whatsapp'.tr()),
                      icon: Icon(
                        Icons.chat,
                        size: 18,
                        color: whatsappBlocked
                            ? Theme.of(context).disabledColor
                            : null,
                      ),
                      tooltip: whatsappBlocked
                          ? 'automation.rules.whatsapp_requires_custom_twilio'.tr()
                          : null,
                    ),
                    ButtonSegment<AutomationChannel>(
                      value: AutomationChannel.internalPush,
                      label: Text('admin.rule_channel_internal_push'.tr()),
                      icon: const Icon(Icons.notifications_active_outlined, size: 18),
                    ),
                  ],
                  selected: {_channel},
                  onSelectionChanged: (next) {
                    if (next.isEmpty) return;
                    if (next.first == AutomationChannel.whatsapp && whatsappBlocked) {
                      return;
                    }
                    _onChannelChanged(next.first);
                  },
                ),
                if (whatsappBlocked) ...[
                  const SizedBox(height: 10),
                  Text(
                    'automation.rules.whatsapp_requires_custom_twilio'.tr(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
                if (_channel == AutomationChannel.internalPush) ...[
                  const SizedBox(height: 16),
                  Text(
                    'admin.rule_staff_recipient'.tr(),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  ref.watch(teamFullListProvider).when(
                        loading: () => const SizedBox(
                          height: 48,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        error: (_, __) => Text(
                          'common.generic_error_user_friendly'.tr(),
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                        data: (team) {
                          final admins = team
                              .where((m) {
                                final sr = (m.systemRole ?? m.role).toLowerCase();
                                return sr == 'admin' || sr == 'manager';
                              })
                              .toList();
                          final sid = _staffProfileId?.trim();
                          final validValue = sid != null &&
                                  sid.isNotEmpty &&
                                  admins.any((m) => m.id == sid)
                              ? sid
                              : null;
                          return DropdownButtonFormField<String>(
                            value: validValue,
                            decoration: InputDecoration(
                              labelText: 'admin.rule_staff_recipient'.tr(),
                            ),
                            items: [
                              for (final m in admins)
                                DropdownMenuItem(
                                  value: m.id,
                                  child: Text(m.name),
                                ),
                            ],
                            onChanged: (v) => setState(() => _staffProfileId = v),
                            validator: (_) {
                              if (_channel != AutomationChannel.internalPush) return null;
                              if (_staffProfileId == null || _staffProfileId!.trim().isEmpty) {
                                return 'admin.rule_validation_staff_required'.tr();
                              }
                              return null;
                            },
                          );
                        },
                      ),
                ],
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'admin.rule_name'.tr(),
                    hintText: 'admin.rule_name_hint'.tr(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'admin.rule_validation_name_required'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _triggerEvent,
                  decoration: InputDecoration(
                    labelText: 'admin.rule_trigger'.tr(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'reservation_check_in',
                      child: Text('automation.trigger_events.reservation_check_in'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'reservation_check_out',
                      child: Text('automation.trigger_events.reservation_check_out'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'task_start',
                      child: Text('automation.trigger_events.task_start'.tr()),
                    ),
                    if (!_knownTriggerEvents.contains(_triggerEvent))
                      DropdownMenuItem(
                        value: _triggerEvent,
                        child: Text('automation.trigger_events.$_triggerEvent'.tr()),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _triggerEvent = v);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _offsetController,
                        decoration: InputDecoration(
                          labelText: 'admin.rule_offset'.tr(),
                          hintText: 'admin.rule_offset_value_hint'.tr(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final raw = v?.trim() ?? '';
                          final val = int.tryParse(raw);
                          if (val == null || val < 0) {
                            return 'admin.rule_validation_offset_required'.tr();
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<_OffsetUnitUi>(
                        initialValue: _offsetUnit,
                        decoration: InputDecoration(
                          labelText: 'admin.rule_offset_unit'.tr(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: _OffsetUnitUi.hours,
                            child: Text('admin.rule_offset_unit_hours'.tr()),
                          ),
                          DropdownMenuItem(
                            value: _OffsetUnitUi.days,
                            child: Text('admin.rule_offset_unit_days'.tr()),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _offsetUnit = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<_OffsetDirectionUi>(
                        initialValue: _offsetDirection,
                        decoration: InputDecoration(
                          labelText: 'admin.rule_offset_direction'.tr(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: _OffsetDirectionUi.before,
                            child: Text('admin.rule_offset_direction_before'.tr()),
                          ),
                          DropdownMenuItem(
                            value: _OffsetDirectionUi.after,
                            child: Text('admin.rule_offset_direction_after'.tr()),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _offsetDirection = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                templatesAsync.when(
                  loading: () => const Center(child: SizedBox(height: 30, child: CircularProgressIndicator())),
                  error: (Object? err, StackTrace? stackTrace) => Text(
                    'admin.rule_templates_load_error'.tr(),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  data: (templates) {
                    if (templates.isEmpty) {
                      return Text(
                        'admin.rule_templates_empty'.tr(),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      );
                    }

                    final filtered = _templatesForSelectedChannel(templates);
                    final selLocal = _selectedTemplateId?.trim();
                    MessageTemplateRow? rowForSelected;
                    if (selLocal != null && selLocal.isNotEmpty) {
                      for (final t in templates) {
                        if (t.id == selLocal) {
                          rowForSelected = t;
                          break;
                        }
                      }
                    }
                    final orphanDeleted =
                        selLocal != null && selLocal.isNotEmpty && rowForSelected == null;
                    final orphanChannelMismatch = rowForSelected != null &&
                        rowForSelected.channel.trim().toLowerCase() != _channel.toDb();
                    final showOrphan = orphanDeleted || orphanChannelMismatch;

                    if (filtered.isEmpty && !showOrphan) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'admin.rule_templates_empty_for_channel'.tr(),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      initialValue: (selLocal != null && selLocal.isNotEmpty) ? selLocal : null,
                      decoration: InputDecoration(
                        labelText: 'admin.rule_template'.tr(),
                      ),
                      items: [
                        if (showOrphan)
                          DropdownMenuItem(
                            value: selLocal,
                            child: Text('admin.rule_template_missing'.tr()),
                          ),
                        for (final t in filtered)
                          DropdownMenuItem(
                            value: t.id,
                            child: Text(t.displayTitleForPicker),
                          ),
                      ],
                      onChanged: (v) => setState(() => _selectedTemplateId = v),
                      validator: (_) {
                        if (_selectedTemplateId == null || _selectedTemplateId!.trim().isEmpty) {
                          return 'admin.rule_validation_template_required'.tr();
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                _QuietHoursPicker(
                  quietStart: _quietStart,
                  quietEnd: _quietEnd,
                  onPickStart: _pickQuietStart,
                  onPickEnd: _pickQuietEnd,
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
        FilledButton.icon(
          onPressed: canSave ? _onSave : null,
          icon: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save, size: 18),
          label: Text('admin.rule_save'.tr()),
        ),
      ],
    );
  }
}

class _QuietHoursPicker extends StatelessWidget {
  /// Picker nočního klidu (quiet hours) pro pravidlo.
  ///
  /// PROČ: Tohle pole mapujeme přímo na `automation_rules.quiet_hours_start`
  /// a `automation_rules.quiet_hours_end` v DB, takže UI drží přesnou interpretaci
  /// "časového okna, kdy se zprávy nesmí odesílat".
  const _QuietHoursPicker({
    required this.quietStart,
    required this.quietEnd,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final TimeOfDay quietStart;
  final TimeOfDay quietEnd;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    final startStr = MaterialLocalizations.of(context).formatTimeOfDay(quietStart);
    final endStr = MaterialLocalizations.of(context).formatTimeOfDay(quietEnd);
    final scheme = Theme.of(context).colorScheme;
    // PROČ: Tonal filled tlačítka dávala tmavé pozadí s tmavým textem (špatný kontrast).
    // OutlinedButton + explicitní barvy z colorScheme zajistí čitelnost v light i dark módu.
    final quietBtnStyle = OutlinedButton.styleFrom(
      foregroundColor: scheme.onSurface,
      side: BorderSide(color: scheme.outline),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurface);
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'admin.rule_quiet_hours'.tr(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: quietBtnStyle,
                onPressed: onPickStart,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin.rule_quiet_hours_start'.tr(),
                      style: labelStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(startStr, style: valueStyle),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: quietBtnStyle,
                onPressed: onPickEnd,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin.rule_quiet_hours_end'.tr(),
                      style: labelStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(endStr, style: valueStyle),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

