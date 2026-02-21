import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/module_model.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';

/// Premium upsell dialog – zobrazí se po kliknutí na zamčenou prémiovou funkci.
/// Načte modul z katalogu (cena), umožní self-service aktivaci se 14denním triálem a zapíše audit.
class PremiumUpsellDialog extends ConsumerStatefulWidget {
  const PremiumUpsellDialog({
    super.key,
    this.moduleKey = 'automatic_tasks',
    this.titleKey = 'admin.module_automatic_tasks_upsell_title',
    this.descriptionKey = 'admin.module_automatic_tasks_upsell_desc',
  });

  final String moduleKey;
  final String titleKey;
  final String descriptionKey;

  /// Otevře premium upsell dialog (modul se načte přes provider, aktivace v dialogu).
  static void show(
    BuildContext context, {
    String moduleKey = 'automatic_tasks',
    String? titleKey,
    String? descriptionKey,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => PremiumUpsellDialog(
        moduleKey: moduleKey,
        titleKey: titleKey ?? 'admin.module_automatic_tasks_upsell_title',
        descriptionKey: descriptionKey ?? 'admin.module_automatic_tasks_upsell_desc',
      ),
    );
  }

  @override
  ConsumerState<PremiumUpsellDialog> createState() => _PremiumUpsellDialogState();
}

class _PremiumUpsellDialogState extends ConsumerState<PremiumUpsellDialog> {
  bool _isActivating = false;

  ModuleModel? _moduleByKey(List<ModuleModel> modules) {
    try {
      return modules.firstWhere((m) => m.key == widget.moduleKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _activateTrial() async {
    if (_isActivating) return;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    final user = ref.read(authNotifierProvider).state.user;
    final modules = ref.read(allModulesProvider).valueOrNull ?? [];
    final module = _moduleByKey(modules);

    if (tenantId == null || tenantId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.premium_activation_error'.tr(namedArgs: {'message': 'No tenant'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (module == null || module.id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.premium_activation_error'.tr(namedArgs: {'message': 'Module not found'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isActivating = true);
    try {
      final trialEndsAt = DateTime.now().toUtc().add(const Duration(days: 14)).toIso8601String();
      await SupabaseService.client.from('tenant_modules').insert({
        'tenant_id': tenantId,
        'module_id': module.id,
        'status': 'active',
        'is_trial': true,
        'trial_ends_at': trialEndsAt,
      });

      await AuditLogService.log(
        tenantId: tenantId,
        userId: user?.id,
        actionType: 'MODULE_ACTIVATED',
        tableName: 'tenant_modules',
        details: {
          'module': widget.moduleKey,
          'price': module.price,
          'trial': true,
          'trial_ends_at': trialEndsAt,
        },
      );

      ref.invalidate(activeModuleKeysProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.premium_activation_success'.tr()),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final isDuplicate = e.code == '23505';
      final message = isDuplicate
          ? 'admin.premium_already_active'.tr()
          : 'admin.premium_activation_error'.tr(namedArgs: {'message': e.message});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (isDuplicate) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.premium_activation_error'.tr(namedArgs: {'message': e.toString()})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final modulesAsync = ref.watch(allModulesProvider);
    final module = modulesAsync.valueOrNull != null
        ? _moduleByKey(modulesAsync.valueOrNull!)
        : null;

    final priceStr = module?.price != null ? module!.price!.toStringAsFixed(0) : '—';
    final currency = 'EUR';
    final primaryLabel = module != null
        ? 'admin.premium_activate_trial'.tr(namedArgs: {'price': priceStr, 'currency': currency})
        : 'admin.premium_upsell_upgrade_btn'.tr();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 40,
                color: primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.titleKey.tr(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.descriptionKey.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
            ),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isActivating ? null : () => Navigator.of(context).pop(),
                child: Text('admin.premium_upsell_cancel_btn'.tr()),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isActivating ? null : _activateTrial,
                child: _isActivating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(primaryLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
