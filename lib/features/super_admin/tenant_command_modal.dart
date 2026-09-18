import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/module_model.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/utils/module_icon_mapper.dart';
import 'package:falconest/features/settings/pricing_type_label.dart';
import 'package:falconest/features/super_admin/module_subscription_dialog.dart';
import 'package:falconest/features/super_admin/providers/all_tenants_provider.dart';
import 'package:falconest/features/super_admin/providers/tenant_detail_provider.dart';
import 'package:falconest/core/utils/app_logger.dart';
import 'package:falconest/core/utils/app_modal_utils.dart';
import 'package:falconest/features/super_admin/tenant_detail_screen.dart';
import 'package:falconest/features/super_admin/services/super_admin_service.dart';

/// Velký modální dialog s přehledem tenanta („Smart Modal“) – Apple/Linear styl.
/// Zobrazuje hero (MRR, uživatelé, byty) a mřížku modulů s okamžitým přepínáním.
/// Otevírá se z dashboardu místo navigace na plnou stránku.
class TenantCommandModal extends ConsumerStatefulWidget {
  const TenantCommandModal({
    super.key,
    required this.tenantId,
    required this.tenantName,
  });

  final String tenantId;
  final String tenantName;

  /// Otevře modal nad aktuálním kontextem (dashboard). Použij místo context.push na detail.
  /// Používá [showAppModal] pro jednotný vizuál napříč aplikací.
  static Future<void> show(BuildContext context, {required String tenantId, required String tenantName}) {
    return showAppModal<void>(
      context: context,
      barrierLabel: 'super_admin.barrier_tenant'.tr(),
      maxWidth: 600,
      maxHeightFraction: 0.88,
      child: _TenantCommandModalContent(
        tenantId: tenantId,
        tenantName: tenantName,
      ),
    );
  }

  @override
  ConsumerState<TenantCommandModal> createState() => _TenantCommandModalState();
}

class _TenantCommandModalState extends ConsumerState<TenantCommandModal> {
  final Map<String, bool> _pendingToggles = {};
  String? _togglingModuleId;

  Future<void> _onModuleTap(ModuleModel module, bool currentlyActive) async {
    if (_togglingModuleId != null) return;
    final newValue = !currentlyActive;

    if (newValue &&
        module.parentModuleKey != null &&
        module.parentModuleKey!.isNotEmpty) {
      final modules = ref.read(allModulesProvider).valueOrNull ?? [];
      final activeIds = ref.read(tenantActiveModuleIdsProvider(widget.tenantId)).valueOrNull ?? {};
      ModuleModel? parent;
      for (final m in modules) {
        if (m.key == module.parentModuleKey) {
          parent = m;
          break;
        }
      }
      if (parent != null && !activeIds.contains(parent.id)) {
        final ok = await _showSubmoduleDependencyDialog(context, module, parent);
        if (!mounted) return;
        if (ok != true) return;
        await _activateBothModules(parent, module);
        return;
      }
    }

    // Při vypínání hlavního modulu: pokud má aktivní sub-moduly, nabídnout kaskádové vypnutí.
    if (!newValue) {
      final modules = ref.read(allModulesProvider).valueOrNull ?? [];
      final activeIds = ref.read(tenantActiveModuleIdsProvider(widget.tenantId)).valueOrNull ?? {};
      final activeDependents = modules
          .where((m) =>
              m.parentModuleKey == module.key &&
              m.parentModuleKey!.isNotEmpty &&
              activeIds.contains(m.id))
          .toList();
      if (activeDependents.isNotEmpty) {
        final ok = await _showDeactivateCascadeDialog(context, module, activeDependents);
        if (!mounted) return;
        if (ok != true) return;
        await _deactivateCascade(module, activeDependents);
        return;
      }
    }

    setState(() {
      _pendingToggles[module.id] = newValue;
      _togglingModuleId = module.id;
    });
    try {
      await SuperAdminService.toggleModule(widget.tenantId, module.id, newValue);
      if (newValue) {
        final auth = ref.read(authNotifierProvider);
        await AuditLogService.log(
          tenantId: auth.tenantIdForData,
          userId: SupabaseService.client.auth.currentUser?.id,
          actionType: 'MODULE_ACTIVATED',
          tableName: 'tenant_modules',
          recordId: module.id,
          details: {'tenant_id': widget.tenantId, 'module_key': module.key},
        );
      } else {
        final auth = ref.read(authNotifierProvider);
        await AuditLogService.log(
          tenantId: auth.tenantIdForData,
          userId: SupabaseService.client.auth.currentUser?.id,
          actionType: 'MODULE_DEACTIVATED',
          tableName: 'tenant_modules',
          recordId: module.id,
          details: {'tenant_id': widget.tenantId, 'module_key': module.key},
        );
      }
      if (!mounted) return;
      ref.invalidate(tenantActiveModuleIdsProvider(widget.tenantId));
      setState(() {
        _pendingToggles.remove(module.id);
        _togglingModuleId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? 'super_admin.module_enabled'.tr(namedArgs: {'name': ModuleIconMapper.displayLabel(module.key, module.name)})
                : 'super_admin.module_disabled'.tr(namedArgs: {'name': ModuleIconMapper.displayLabel(module.key, module.name)}),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingToggles.remove(module.id);
        _togglingModuleId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.module_toggle_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Dialog před kaskádovým vypnutím hlavního modulu a jeho aktivních sub-modulů.
  /// useRootNavigator: true – aby dialog byl nad rozmazaným pozadím modalu a byl klikatelný.
  Future<bool?> _showDeactivateCascadeDialog(
    BuildContext context,
    ModuleModel mainModule,
    List<ModuleModel> activeDependents,
  ) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text('super_admin.module_deactivate_cascade_title'.tr()),
        content: Text('super_admin.module_deactivate_cascade_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text('super_admin.module_deactivate_cascade_confirm'.tr()),
          ),
        ],
      ),
    );
  }

  /// Vypne hlavní modul a všechny zadané aktivní sub-moduly; u každého zapíše MODULE_DEACTIVATED.
  Future<void> _deactivateCascade(ModuleModel mainModule, List<ModuleModel> activeDependents) async {
    final toDeactivate = [mainModule, ...activeDependents];
    for (final m in toDeactivate) {
      setState(() {
        _pendingToggles[m.id] = false;
        _togglingModuleId = m.id;
      });
    }
    final auth = ref.read(authNotifierProvider);
    final userId = SupabaseService.client.auth.currentUser?.id;
    try {
      for (final m in toDeactivate) {
        await SuperAdminService.toggleModule(widget.tenantId, m.id, false);
        await AuditLogService.log(
          tenantId: auth.tenantIdForData,
          userId: userId,
          actionType: 'MODULE_DEACTIVATED',
          tableName: 'tenant_modules',
          recordId: m.id,
          details: {'tenant_id': widget.tenantId, 'module_key': m.key},
        );
      }
      if (!mounted) return;
      ref.invalidate(tenantActiveModuleIdsProvider(widget.tenantId));
      for (final m in toDeactivate) {
        setState(() => _pendingToggles.remove(m.id));
      }
      setState(() => _togglingModuleId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.module_disabled'.tr(namedArgs: {'name': ModuleIconMapper.displayLabel(mainModule.key, mainModule.name)})),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      for (final m in toDeactivate) {
        setState(() => _pendingToggles.remove(m.id));
      }
      setState(() => _togglingModuleId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.module_toggle_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatTrialDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _openModuleSubscriptionDialog(ModuleModel module, TenantModuleSubscriptionData? sub) async {
    await ModuleSubscriptionDialog.show(
      context,
      tenantId: widget.tenantId,
      module: module,
      initialIsTrial: sub?.isTrial ?? false,
      initialTrialEndsAt: sub?.trialEndsAt,
      initialValidUntil: sub?.validUntil,
    );
    if (!mounted) return;
    ref.invalidate(tenantModuleSubscriptionMapProvider(widget.tenantId));
  }

  Future<bool?> _showSubmoduleDependencyDialog(
    BuildContext context,
    ModuleModel subModule,
    ModuleModel parentModule,
  ) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text('super_admin.submodule_dependency_title'.tr()),
        content: Text('super_admin.submodule_dependency_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('super_admin.submodule_activate_both'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _activateBothModules(ModuleModel parent, ModuleModel subModule) async {
    setState(() {
      _pendingToggles[parent.id] = true;
      _pendingToggles[subModule.id] = true;
      _togglingModuleId = subModule.id;
    });
    final auth = ref.read(authNotifierProvider);
    final userId = SupabaseService.client.auth.currentUser?.id;
    try {
      await SuperAdminService.toggleModule(widget.tenantId, parent.id, true);
      await AuditLogService.log(
        tenantId: auth.tenantIdForData,
        userId: userId,
        actionType: 'MODULE_ACTIVATED',
        tableName: 'tenant_modules',
        recordId: parent.id,
        details: {'tenant_id': widget.tenantId, 'module_key': parent.key},
      );
      await SuperAdminService.toggleModule(widget.tenantId, subModule.id, true);
      await AuditLogService.log(
        tenantId: auth.tenantIdForData,
        userId: userId,
        actionType: 'MODULE_ACTIVATED',
        tableName: 'tenant_modules',
        recordId: subModule.id,
        details: {'tenant_id': widget.tenantId, 'module_key': subModule.key},
      );
      if (!mounted) return;
      ref.invalidate(tenantActiveModuleIdsProvider(widget.tenantId));
      setState(() {
        _pendingToggles.remove(parent.id);
        _pendingToggles.remove(subModule.id);
        _togglingModuleId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.module_enabled'.tr(namedArgs: {'name': ModuleIconMapper.displayLabel(subModule.key, subModule.name)})),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingToggles.remove(parent.id);
        _pendingToggles.remove(subModule.id);
        _togglingModuleId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.module_toggle_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onLoginAs() async {
    try {
      await ref.read(authNotifierProvider).impersonateTenant(widget.tenantId);
      if (!mounted) return;
      ref.invalidate(tenantDetailProvider(widget.tenantId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.impersonate_success'.tr(namedArgs: {'name': widget.tenantName})),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
      context.go('/admin');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.impersonate_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Smazání agentury z modalu: potvrzení → smazání invitations a tenanta → zavření modalu a invalidace seznamu.
  Future<void> _onDeleteTenant() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('super_admin.delete_confirm_title'.tr()),
        content: Text('super_admin.delete_confirm_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('super_admin.btn_delete'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await SupabaseService.client.from('invitations').delete().eq('tenant_id', widget.tenantId);
    } catch (e, st) {
      AppLogger.error('TenantCommandModal: mazání invitations před soft-delete tenanta selhalo', e, st);
    }
    try {
      // Soft Delete: místo tvrdého DELETE nastavíme deleted_at – zachová Audit Log a historii dat.
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.client
          .from('tenants')
          .update({'deleted_at': deletedAt})
          .eq('id', widget.tenantId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'common.error'.tr()}: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    ref.invalidate(tenantsWithStatusProvider);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('super_admin.agency_deleted'.tr()),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeroSection(context),
                        const SizedBox(height: 24),
                        _buildModulesGrid(context),
                      ],
                    ),
                  ),
                ),
              ],
            );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.tenantName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
            tooltip: 'super_admin.menu_delete'.tr(),
            onPressed: _onDeleteTenant,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              TenantDetailModal.show(context, widget.tenantId, tenantName: widget.tenantName);
            },
            icon: const Icon(Icons.visibility, size: 20),
            label: Text('super_admin.tenant_detail_btn'.tr()),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _onLoginAs,
            icon: const Icon(Icons.login_rounded, size: 20),
            label: Text('super_admin.login_as'.tr()),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    final detailAsync = ref.watch(tenantDetailProvider(widget.tenantId));
    final statsFullAsync = ref.watch(tenantStatsFullProvider(widget.tenantId));
    final modulesAsync = ref.watch(allModulesProvider);
    final activeAsync = ref.watch(tenantActiveModuleIdsProvider(widget.tenantId));
    final subscriptionMap = ref.watch(tenantModuleSubscriptionMapProvider(widget.tenantId)).valueOrNull ?? {};
    final profilesAsync = ref.watch(tenantProfilesProvider(widget.tenantId));
    final currenciesAsync = ref.watch(currenciesProvider);
    final displayCurrency = ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';

    return detailAsync.when(
      data: (detail) {
        final statsFull = statsFullAsync.valueOrNull ?? const TenantStatsFull();
        final tenantCurrency = detail?.currency ?? 'CZK';
        final pricePerApt = (detail?.pricePerApartment ?? 0).toDouble();
        final discountPct = (detail?.discountPercentage ?? 0).clamp(0, 100);
        final currencies = currenciesAsync.valueOrNull ?? [];
        final apartmentCount = statsFull.apartmentCount;
        final userCount = profilesAsync.valueOrNull?.length ?? 0;

        double totalModuleEur = 0;
        if (modulesAsync.valueOrNull != null && activeAsync.valueOrNull != null) {
          final modules = modulesAsync.valueOrNull!;
          final activeIds = activeAsync.valueOrNull!;
          for (final m in modules) {
            final on_ = _pendingToggles.containsKey(m.id) ? _pendingToggles[m.id]! : activeIds.contains(m.id);
            final isTrial = subscriptionMap[m.id]?.isTrial == true;
            if (on_ && !isTrial) {
              final priceEur = m.price?.toDouble() ?? 0;
              switch (m.pricingType) {
                case 'per_apartment':
                  totalModuleEur += priceEur * apartmentCount;
                  break;
                case 'per_user':
                  totalModuleEur += priceEur * userCount;
                  break;
                default:
                  totalModuleEur += priceEur;
              }
            }
          }
        }
        final baseInTenantCurrency = pricePerApt * apartmentCount;
        final baseInEur = currencies.isEmpty
            ? 0.0
            : CurrencyService.toEur(baseInTenantCurrency, tenantCurrency, currencies);
        final subtotalEur = totalModuleEur + baseInEur;
        final totalEur = subtotalEur * (1 - (discountPct / 100));
        final mrrStr = currencies.isEmpty
            ? '€ ${totalEur.toStringAsFixed(2)}'
            : CurrencyService.formatPrice(totalEur, displayCurrency, currencies);
        var invoicedInText = 'super_admin.invoiced_in'.tr(namedArgs: {'currency': tenantCurrency});
        if (discountPct > 0) {
          invoicedInText += '\n${'super_admin.mrr_discount_applied'.tr(namedArgs: {'percent': '$discountPct'})}';
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _HeroCard(
                  title: 'super_admin.mrr_per_month_short'.tr(namedArgs: {'amount': mrrStr}),
                  subtitle: 'super_admin.mrr_short'.tr(),
                  invoicedIn: invoicedInText,
                  icon: Icons.euro_rounded,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroCard(
                  title: 'super_admin.users_active_pending'.tr(
                    namedArgs: {'active': '${statsFull.activeUsers}', 'pending': '${statsFull.pendingInvitations}'},
                  ),
                  subtitle: 'super_admin.section_team'.tr(),
                  icon: Icons.people_rounded,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroCard(
                  title: '${statsFull.apartmentCount}',
                  subtitle: 'super_admin.managed_units'.tr(),
                  icon: Icons.apartment_rounded,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (_, _) => const SizedBox(height: 80, child: Center(child: Icon(Icons.error_outline, size: 48))),
    );
  }

  Widget _buildModulesGrid(BuildContext context) {
    final modulesAsync = ref.watch(allModulesProvider);
    final activeAsync = ref.watch(tenantActiveModuleIdsProvider(widget.tenantId));
    final subscriptionMap = ref.watch(tenantModuleSubscriptionMapProvider(widget.tenantId)).valueOrNull ?? {};
    final currenciesAsync = ref.watch(currenciesProvider);
    final displayCurrency = ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';

    return modulesAsync.when(
      data: (modules) {
        if (modules.isEmpty) {
          return Text(
            'super_admin.module_list_empty'.tr(),
            style: TextStyle(color: Colors.grey[600]),
          );
        }
        final activeIds = activeAsync.valueOrNull ?? {};
        final currencies = currenciesAsync.valueOrNull ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'super_admin.section_modules'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (_, constraints) {
                const crossAxisCount = 3;
                const spacing = 8.0;
                final width = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: modules.map((module) {
                    final isOn = _pendingToggles.containsKey(module.id)
                        ? _pendingToggles[module.id]!
                        : activeIds.contains(module.id);
                    final isToggling = _togglingModuleId == module.id;
                    final sub = subscriptionMap[module.id];
                    final trialBadge = (sub != null && sub.isTrial && sub.trialEndsAt != null)
                        ? 'super_admin.module_trial_badge'.tr(namedArgs: {'date': _formatTrialDate(sub.trialEndsAt!)})
                        : null;
                    final priceStr = module.price != null && currencies.isNotEmpty
                        ? CurrencyService.formatPrice(module.price!.toDouble(), displayCurrency, currencies)
                        : (module.price != null ? '${module.price} €' : 'common.placeholder_dash'.tr());
                    return SizedBox(
                      width: width,
                      child: _ModuleCard(
                        module: module,
                        isActive: isOn,
                        priceStr: priceStr,
                        isToggling: isToggling,
                        trialBadge: trialBadge,
                        onTap: () => _onModuleTap(module, isOn),
                        onSettingsTap: isOn ? () => _openModuleSubscriptionDialog(module, sub) : null,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      error: (e, _) => Text('common.generic_error_user_friendly'.tr()),
    );
  }
}

class _TenantCommandModalContent extends ConsumerWidget {
  const _TenantCommandModalContent({
    required this.tenantId,
    required this.tenantName,
  });

  final String tenantId;
  final String tenantName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TenantCommandModal(tenantId: tenantId, tenantName: tenantName);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.invoicedIn,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  /// Volitelný text pod subtitle (např. "Fakturace v: CZK" u MRR karty).
  final String? invoicedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          if (invoicedIn != null && invoicedIn!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              invoicedIn!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.isActive,
    required this.priceStr,
    required this.isToggling,
    this.trialBadge,
    required this.onTap,
    this.onSettingsTap,
  });

  final ModuleModel module;
  final bool isActive;
  final String priceStr;
  final bool isToggling;
  final String? trialBadge;
  final VoidCallback onTap;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? Colors.white : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      elevation: isActive ? 2 : 0,
      shadowColor: Colors.black26,
      child: SizedBox(
        height: 120,
        child: Stack(
          children: [
            Positioned.fill(
              child: InkWell(
                onTap: isToggling ? null : onTap,
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isToggling)
                        const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Icon(
                          ModuleIconMapper.getIcon(module.key),
                          size: 28,
                          color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        ModuleIconMapper.displayLabel(module.key, module.name),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          color: isActive ? Colors.grey[900] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        priceStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive ? Colors.grey[700] : Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        getPricingTypeLabelKey(module.pricingType).tr(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (trialBadge != null)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    trialBadge!,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (onSettingsTap != null)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.settings),
                  iconSize: 18,
                  color: Colors.grey,
                  onPressed: onSettingsTap,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Jednoduchý dialog pro úpravu názvu, fakturačních údajů a měny tenanta (skryté v modalu pod „Edit Info“).
class _TenantEditInfoDialog extends ConsumerStatefulWidget {
  const _TenantEditInfoDialog({
    required this.tenantId,
    required this.onSaved,
  });

  final String tenantId;
  final VoidCallback onSaved;

  @override
  ConsumerState<_TenantEditInfoDialog> createState() => _TenantEditInfoDialogState();
}

class _TenantEditInfoDialogState extends ConsumerState<_TenantEditInfoDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _companyController;
  late TextEditingController _icoController;
  late TextEditingController _dicController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _zipController;
  late TextEditingController _countryController;
  late TextEditingController _contactEmailController;
  late TextEditingController _phoneController;
  late TextEditingController _discountController;
  String _currency = 'CZK';
  bool _loading = true;
  bool _saving = false;
  bool _initialPopulateScheduled = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _companyController = TextEditingController();
    _icoController = TextEditingController();
    _dicController = TextEditingController();
    _streetController = TextEditingController();
    _cityController = TextEditingController();
    _zipController = TextEditingController();
    _countryController = TextEditingController();
    _contactEmailController = TextEditingController();
    _phoneController = TextEditingController();
    _discountController = TextEditingController();
  }

  /// Naplní controllery z načteného detailu tenanta (BillingInfo + root sloupce currency, discount_percentage).
  void _populateFromDetail(TenantDetailRow detail) {
    _nameController.text = detail.name;
    final b = detail.billingInfo;
    _companyController.text = b?.companyName ?? '';
    _icoController.text = b?.ico ?? '';
    _dicController.text = b?.dic ?? '';
    _streetController.text = b?.street ?? '';
    _cityController.text = b?.city ?? '';
    _zipController.text = b?.zip ?? '';
    _countryController.text = b?.country ?? '';
    _contactEmailController.text = b?.contactEmail ?? '';
    _phoneController.text = b?.phone ?? '';
    _currency = detail.currency ?? 'CZK';
    _discountController.text = '${detail.discountPercentage}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _icoController.dispose();
    _dicController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _contactEmailController.dispose();
    _phoneController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(tenantDetailProvider(widget.tenantId));
    final currenciesAsync = ref.watch(currenciesProvider);

    // Když už máme data (cache nebo právě došlá) a ještě jsme neprefillovali – naplníme controllery.
    // ref.listen reaguje jen na ZMĚNU; při otevření z cache se nevolá, proto řešíme i tady.
    final detail = detailAsync.valueOrNull;
    if (detail != null && _loading && !_initialPopulateScheduled) {
      _initialPopulateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _populateFromDetail(detail);
        setState(() => _loading = false);
      });
    }

    ref.listen(tenantDetailProvider(widget.tenantId), (prev, next) {
      next.whenData((d) {
        if (d != null && _loading) {
          _populateFromDetail(d);
          if (mounted) setState(() => _loading = false);
        }
      });
    });

    return AlertDialog(
      title: Text('super_admin.edit_info'.tr()),
      content: SizedBox(
        width: 400,
        child: _loading && detailAsync.valueOrNull == null
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'super_admin.field_agency_name'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _companyController,
                      decoration: InputDecoration(
                        labelText: 'super_admin.billing_company_name'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _icoController,
                      decoration: InputDecoration(
                        labelText: 'super_admin.billing_ico'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dicController,
                      decoration: InputDecoration(
                        labelText: 'super_admin.billing_dic'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _streetController,
                      decoration: InputDecoration(
                        labelText: 'super_admin.billing_street'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _cityController,
                            decoration: InputDecoration(
                              labelText: 'super_admin.billing_city'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _zipController,
                            decoration: InputDecoration(
                              labelText: 'super_admin.billing_zip'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _countryController,
                      decoration: InputDecoration(
                        labelText: 'super_admin.billing_country'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _contactEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'super_admin.billing_contact_email'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'super_admin.billing_phone'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ['CZK', 'EUR', 'USD'].contains(_currency)
                          ? _currency
                          : 'CZK',
                      decoration: InputDecoration(
                        labelText: 'super_admin.billing_currency'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      items: (currenciesAsync.valueOrNull ?? []).isEmpty
                          ? ['CZK', 'EUR', 'USD']
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList()
                          : (currenciesAsync.valueOrNull!)
                              .map((c) => DropdownMenuItem(value: c.code, child: Text('${c.code} ${c.symbol}')))
                              .toList(),
                      onChanged: (v) => setState(() => _currency = v ?? 'CZK'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'super_admin.discount_percentage_label'.tr(),
                        border: const OutlineInputBorder(),
                        hintText: 'super_admin.discount_placeholder'.tr(),
                      ),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return null;
                        final n = int.tryParse(s);
                        if (n == null || n < 0 || n > 100) {
                          return 'super_admin.discount_validation'.tr();
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
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('common.save'.tr()),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // Sestavíme BillingInfo z hodnot formuláře (včetně contactEmail a phone).
      final billing = BillingInfo(
        companyName: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
        ico: _icoController.text.trim().isEmpty ? null : _icoController.text.trim(),
        dic: _dicController.text.trim().isEmpty ? null : _dicController.text.trim(),
        street: _streetController.text.trim().isEmpty ? null : _streetController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        zip: _zipController.text.trim().isEmpty ? null : _zipController.text.trim(),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        contactEmail: _contactEmailController.text.trim().isEmpty ? null : _contactEmailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );

      final discountStr = _discountController.text.trim();
      final discountPct = discountStr.isEmpty ? 0 : (int.tryParse(discountStr) ?? 0).clamp(0, 100);

      await SupabaseService.client.from('tenants').update({
        'name': _nameController.text.trim(),
        'currency': _currency,
        'billing_info': billing.toJson(),
        'discount_percentage': discountPct,
      }).eq('id', widget.tenantId);

      if (!mounted) return;
      ref.invalidate(tenantDetailProvider(widget.tenantId));
      ref.invalidate(tenantsWithStatusProvider);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.billing_saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'common.error'.tr()}: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
