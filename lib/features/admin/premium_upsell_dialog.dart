import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';
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
  /// Null = ještě neznáme, true = trial vypršel → zobrazit „Koupit plnou verzi“, false = zobrazit „Aktivovat trial“.
  bool? _trialExpired;
  bool _trialCheckStarted = false;
  bool _activeModuleHandled = false;

  ModuleModel? _moduleByKey(List<ModuleModel> modules) {
    try {
      return modules.firstWhere((m) => m.key == widget.moduleKey);
    } catch (e, st) {
      AppLogger.error('PremiumUpsellDialog._moduleByKey: modul s daným klíčem nenalezen nebo chyba', e, st);
      return null;
    }
  }

  /// Načte stav trialu z tenant_modules – pokud trial_ends_at je v minulosti, zobrazíme „Koupit plnou verzi“.
  Future<void> _loadTrialState(String tenantId, String moduleId) async {
    if (_trialCheckStarted) return;
    _trialCheckStarted = true;
    try {
      final existing = await SupabaseService.safeFrom('tenant_modules', tenantId)
          .select('trial_ends_at')
          .eq('module_id', moduleId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (!mounted) return;
      final raw = existing?['trial_ends_at'];
      DateTime? trialEndsAt;
      if (raw is DateTime) {
        trialEndsAt = raw.toUtc();
      } else if (raw is String) {
        trialEndsAt = DateTime.tryParse(raw)?.toUtc();
      }
      final now = DateTime.now().toUtc();
      setState(() {
        _trialExpired = trialEndsAt != null && trialEndsAt.isBefore(now);
      });
    } catch (e, st) {
      AppLogger.error('PremiumUpsellDialog._loadTrialState: načtení trial_ends_at selhalo', e, st);
      if (mounted) setState(() => _trialExpired = false);
    }
  }

  /// Zobrazí nativní potvrzovací dialog nákupu; při souhlasu provede UPDATE a uzavře flow.
  Future<void> _showPurchaseConfirmAndRun(ModuleModel module, String tenantId) async {
    final priceStr = module.price?.toStringAsFixed(0) ?? '0';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('admin.premium_buy_confirm_title'.tr()),
        content: Text(
          'admin.premium_buy_confirm_message'.tr(namedArgs: {'price': priceStr}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('admin.premium_upsell_cancel_btn'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('admin.premium_buy_confirm_btn'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _purchaseModule(tenantId, module);
  }

  /// Check-then-Act: UPDATE tenant_modules na plnou verzi, audit, invalidace, úspěšný SnackBar.
  Future<void> _purchaseModule(String tenantId, ModuleModel module) async {
    final user = ref.read(authNotifierProvider).state.user;
    setState(() => _isActivating = true);
    try {
      final validUntil = DateTime.now().toUtc().add(const Duration(days: 31)).toIso8601String();
      await SupabaseService.safeFrom('tenant_modules', tenantId).update({
        'status': 'active',
        'is_trial': false,
        'trial_ends_at': null,
        'valid_until': validUntil,
        'deleted_at': null,
      }).eq('module_id', module.id);

      await AuditLogService.log(
        tenantId: tenantId,
        userId: user?.id,
        actionType: 'MODULE_PURCHASED',
        tableName: 'tenant_modules',
        details: {
          'module': widget.moduleKey,
          'price': module.price,
          'valid_until': validUntil,
          'self_service': true,
        },
      );

      ref.invalidate(activeModuleKeysProvider);
      ref.invalidate(tenantActiveModuleIdsProvider(tenantId));

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.premium_buy_success'.tr()),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('premium purchase Postgrest: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      if (mounted) setState(() => _isActivating = false);
    }
  }

  Future<void> _activateTrial() async {
    if (kDebugMode) {
      debugPrint('[PremiumUpsellDialog] _activateTrial click module=${widget.moduleKey}');
    }
    if (_isActivating) return;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    final user = ref.read(authNotifierProvider).state.user;
    final modules = ref.read(allModulesProvider).valueOrNull ?? [];
    final module = _moduleByKey(modules);

    if (tenantId == null || tenantId.isEmpty) {
      if (kDebugMode) {
        debugPrint('[PremiumUpsellDialog] _activateTrial aborted: missing tenantId');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error_no_tenant'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (module == null || module.id.isEmpty) {
      if (kDebugMode) {
        debugPrint('[PremiumUpsellDialog] _activateTrial aborted: module not found for key=${widget.moduleKey}');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.premium_module_not_found'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isActivating = true);
    try {
      // 1. Dotaz na existenci záznamu (Check-then-Act – ochrana proti nekonečnému trialu).
      final existing = await SupabaseService.safeFrom('tenant_modules', tenantId)
          .select('trial_ends_at, deleted_at, valid_until, is_trial')
          .eq('module_id', module.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final now = DateTime.now().toUtc();

      if (existing == null) {
        // A) Uživatel modul nikdy neměl – standardní INSERT s 14denním triálem.
        final trialEndsAt = now.add(const Duration(days: 14)).toIso8601String();
        await SupabaseService.safeFrom('tenant_modules', tenantId).insert({
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
      } else {
        // B) Záznam existuje – kontrolujeme, zda trial nevypršel.
        final raw = existing['trial_ends_at'];
        DateTime? trialEndsAt;
        if (raw is DateTime) {
          trialEndsAt = raw.toUtc();
        } else if (raw is String) {
          trialEndsAt = DateTime.tryParse(raw)?.toUtc();
        }

        if (trialEndsAt != null && trialEndsAt.isBefore(now)) {
          if (kDebugMode) {
            debugPrint('[PremiumUpsellDialog] trial expired -> purchase flow module=${widget.moduleKey}');
          }
          // Trial vypršel – místo chybové hlášky nabídneme nákup (potvrzovací dialog + _purchaseModule).
          if (!mounted) return;
          await _showPurchaseConfirmAndRun(module, tenantId);
          return;
        }

        // Trial stále běží nebo bez data – pouze obnovíme zapnutí (update, neměníme trial_ends_at).
        await SupabaseService.safeFrom('tenant_modules', tenantId)
            .update({
              'status': 'active',
              'deleted_at': null,
              'cancel_at_period_end': false,
            })
            .eq('module_id', module.id);

        await AuditLogService.log(
          tenantId: tenantId,
          userId: user?.id,
          actionType: 'MODULE_REACTIVATED',
          tableName: 'tenant_modules',
          details: {'module': widget.moduleKey},
        );
      }

      ref.invalidate(activeModuleKeysProvider);
      ref.invalidate(tenantActiveModuleIdsProvider(tenantId));

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
      if (kDebugMode) debugPrint('premium trial Postgrest: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.generic_error_user_friendly'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      if (mounted) setState(() => _isActivating = false);
    }
  }

  /// Spustí nákup (potvrzovací dialog + UPDATE). Volá se po kliknutí na „Koupit plnou verzi“.
  Future<void> _onBuyFullVersion() async {
    if (kDebugMode) {
      debugPrint('[PremiumUpsellDialog] _onBuyFullVersion click module=${widget.moduleKey}');
    }
    if (_isActivating) return;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    final modules = ref.read(allModulesProvider).valueOrNull ?? [];
    final module = _moduleByKey(modules);
    if (tenantId == null || tenantId.isEmpty) {
      if (kDebugMode) {
        debugPrint('[PremiumUpsellDialog] _onBuyFullVersion aborted: missing tenantId');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.error_no_tenant'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (module == null) {
      if (kDebugMode) {
        debugPrint('[PremiumUpsellDialog] _onBuyFullVersion aborted: module not found for key=${widget.moduleKey}');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin.premium_module_not_found'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _showPurchaseConfirmAndRun(module, tenantId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final modulesAsync = ref.watch(allModulesProvider);
    final module = modulesAsync.valueOrNull != null
        ? _moduleByKey(modulesAsync.valueOrNull!)
        : null;
    final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
    final moduleAlreadyActive = isModuleActive(ref, widget.moduleKey);

    // Pokud je modul aktivní (např. ručně zapnutý Super-Adminem), upsell se nemá zobrazovat.
    // Dialog se zavře a uživatel dostane potvrzení, že modul je dostupný.
    if (moduleAlreadyActive && !_activeModuleHandled) {
      _activeModuleHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (kDebugMode) {
          debugPrint('[PremiumUpsellDialog] bypass: module already active key=${widget.moduleKey}');
        }
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin.premium_activation_success'.tr()),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
      return const SizedBox.shrink();
    }

    // Jednorázově načteme stav trialu (vypršený → zobrazit „Koupit plnou verzi“).
    if (!moduleAlreadyActive &&
        module != null &&
        tenantId != null &&
        tenantId.isNotEmpty &&
        !_trialCheckStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTrialState(tenantId, module.id);
      });
    }

    final priceStr = module?.price != null ? module!.price!.toStringAsFixed(0) : 'common.placeholder_dash'.tr();
    final currency = 'EUR';
    final isExpired = _trialExpired == true;
    final primaryLabel = module != null
        ? (isExpired
            ? 'admin.premium_buy_module'.tr(namedArgs: {'price': priceStr})
            : 'admin.premium_activate_trial'.tr(namedArgs: {'price': priceStr, 'currency': currency}))
        : 'admin.premium_upsell_upgrade_btn'.tr();
    final onPrimaryPressed = isExpired ? _onBuyFullVersion : _activateTrial;

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
                onPressed: _isActivating ? null : onPrimaryPressed,
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
