import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/module_model.dart';
import 'package:falconest/features/admin/utils/module_icon_mapper.dart';
import 'package:falconest/features/super_admin/providers/tenant_detail_provider.dart';
import 'package:falconest/features/super_admin/services/super_admin_service.dart';

/// Dialog pro správu trialu a platnosti modulu (Marketing & Předplatné).
/// Zobrazuje přepínač trial, datum konce trialu a manuální platnost (pro budoucí Fakturaci).
/// Po uložení zapíše audit TRIAL_UPDATED a invaliduje [tenantModuleSubscriptionMapProvider].
class ModuleSubscriptionDialog extends ConsumerStatefulWidget {
  const ModuleSubscriptionDialog({
    super.key,
    required this.tenantId,
    required this.module,
    required this.initialIsTrial,
    this.initialTrialEndsAt,
    this.initialValidUntil,
  });

  final String tenantId;
  final ModuleModel module;
  final bool initialIsTrial;
  final DateTime? initialTrialEndsAt;
  final DateTime? initialValidUntil;

  /// Otevře dialog; po uložení vrací true (volající má invalidovat provider).
  static Future<bool?> show(
    BuildContext context, {
    required String tenantId,
    required ModuleModel module,
    required bool initialIsTrial,
    DateTime? initialTrialEndsAt,
    DateTime? initialValidUntil,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ModuleSubscriptionDialog(
        tenantId: tenantId,
        module: module,
        initialIsTrial: initialIsTrial,
        initialTrialEndsAt: initialTrialEndsAt,
        initialValidUntil: initialValidUntil,
      ),
    );
  }

  @override
  ConsumerState<ModuleSubscriptionDialog> createState() => _ModuleSubscriptionDialogState();
}

class _ModuleSubscriptionDialogState extends ConsumerState<ModuleSubscriptionDialog> {
  late bool _isTrial;
  DateTime? _trialEndsAt;
  DateTime? _validUntil;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isTrial = widget.initialIsTrial;
    _trialEndsAt = widget.initialTrialEndsAt;
    _validUntil = widget.initialValidUntil;
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final initial = current ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) onPicked(d);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await SuperAdminService.updateTenantModuleTrial(
        widget.tenantId,
        widget.module.id,
        isTrial: _isTrial,
        trialEndsAt: _isTrial ? _trialEndsAt : null,
        validUntil: _validUntil,
      );
      final auth = ref.read(authNotifierProvider);
      await AuditLogService.log(
        tenantId: auth.tenantIdForData,
        userId: SupabaseService.client.auth.currentUser?.id,
        actionType: 'TRIAL_UPDATED',
        tableName: 'tenant_modules',
        recordId: widget.module.id,
        details: {
          'tenant_id': widget.tenantId,
          'module_key': widget.module.key,
          'is_trial': _isTrial,
          'trial_ends_at': _trialEndsAt?.toIso8601String(),
          'valid_until': _validUntil?.toIso8601String(),
        },
      );
      if (!mounted) return;
      ref.invalidate(tenantModuleSubscriptionMapProvider(widget.tenantId));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.module_trial_update_error'.tr(namedArgs: {'error': '$e'})),
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
    final moduleName = ModuleIconMapper.getLabelKey(widget.module.key).tr();
    return AlertDialog(
      title: Text('super_admin.module_subscription_dialog_title'.tr(namedArgs: {'name': moduleName})),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: Text('super_admin.module_trial_switch'.tr()),
              value: _isTrial,
              onChanged: _saving
                  ? null
                  : (v) {
                      setState(() {
                        _isTrial = v;
                        if (!v) _trialEndsAt = null;
                      });
                    },
            ),
            if (_isTrial) ...[
              const SizedBox(height: 8),
              ListTile(
                title: Text('super_admin.module_trial_ends_label'.tr()),
                subtitle: Text(_formatDate(_trialEndsAt).isEmpty ? '—' : _formatDate(_trialEndsAt)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _saving ? null : () => _pickDate(current: _trialEndsAt, onPicked: (d) => setState(() => _trialEndsAt = d)),
              ),
            ],
            const SizedBox(height: 8),
            ListTile(
              title: Text('super_admin.module_valid_until_label'.tr()),
              subtitle: Text(_formatDate(_validUntil).isEmpty ? '—' : _formatDate(_validUntil)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _saving ? null : () => _pickDate(current: _validUntil, onPicked: (d) => setState(() => _validUntil = d)),
            ),
            const SizedBox(height: 4),
            Text(
              'super_admin.module_valid_until_hint'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('common.save'.tr()),
        ),
      ],
    );
  }
}
