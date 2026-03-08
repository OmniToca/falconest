import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/module_model.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/utils/module_icon_mapper.dart';
import 'package:falconest/features/settings/pricing_type_label.dart';
import 'package:falconest/features/super_admin/providers/tenant_detail_provider.dart';
import 'package:falconest/features/super_admin/services/super_admin_service.dart';

/// Záložka Fakturace v klientském Nastavení – fakturační údaje, přehled předplatného a historie faktur.
///
/// Klient si sám spravuje fakturační údaje, aby to nemusel dělat Super Admin.
/// Zobrazuje se pouze uživatelům s rolí admin nebo manager (viz settings_screen.dart).
class ClientBillingTab extends ConsumerStatefulWidget {
  const ClientBillingTab({super.key});

  @override
  ConsumerState<ClientBillingTab> createState() => _ClientBillingTabState();
}

class _ClientBillingTabState extends ConsumerState<ClientBillingTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _companyNameController = TextEditingController();
  final _icoController = TextEditingController();
  final _dicController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _countryController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _initialized = false;
  bool _dirty = false;
  bool _saving = false;

  /// Optimistický stav přepínačů modulů – zobrazí se okamžitě před reload providera.
  final Map<String, bool> _pendingToggles = {};
  String? _togglingModuleId;

  @override
  void initState() {
    super.initState();
    void markDirty() => setState(() => _dirty = true);
    _companyNameController.addListener(markDirty);
    _icoController.addListener(markDirty);
    _dicController.addListener(markDirty);
    _streetController.addListener(markDirty);
    _cityController.addListener(markDirty);
    _zipController.addListener(markDirty);
    _countryController.addListener(markDirty);
    _contactEmailController.addListener(markDirty);
    _phoneController.addListener(markDirty);
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _icoController.dispose();
    _dicController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _contactEmailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initFromBilling(BillingInfo? info) {
    if (_initialized) return;
    _initialized = true;
    _companyNameController.text = info?.companyName ?? '';
    _icoController.text = info?.ico ?? '';
    _dicController.text = info?.dic ?? '';
    _streetController.text = info?.street ?? '';
    _cityController.text = info?.city ?? '';
    _zipController.text = info?.zip ?? '';
    _countryController.text = info?.country ?? '';
    _contactEmailController.text = info?.contactEmail ?? '';
    _phoneController.text = info?.phone ?? '';
  }

  Future<void> _saveBilling() async {
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      final billing = BillingInfo(
        companyName: _companyNameController.text.trim().isEmpty
            ? null
            : _companyNameController.text.trim(),
        ico: _icoController.text.trim().isEmpty ? null : _icoController.text.trim(),
        dic: _dicController.text.trim().isEmpty ? null : _dicController.text.trim(),
        street: _streetController.text.trim().isEmpty ? null : _streetController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        zip: _zipController.text.trim().isEmpty ? null : _zipController.text.trim(),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        contactEmail: _contactEmailController.text.trim().isEmpty
            ? null
            : _contactEmailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );

      await SupabaseService.client
          .from('tenants')
          .update({'billing_info': billing.toJson()})
          .eq('id', tenantId);

      ref.invalidate(tenantDetailProvider(tenantId));
      setState(() {
        _dirty = false;
        _saving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.billing_saved'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'settings.billing_save_error'.tr(namedArgs: {'message': e.toString()}),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final tenantId = ref.watch(authNotifierProvider).tenantIdForData;
    final tenantAsync = tenantId != null && tenantId.isNotEmpty
        ? ref.watch(tenantDetailProvider(tenantId))
        : const AsyncValue.data(null);
    final activeKeysAsync = ref.watch(activeModuleKeysProvider);
    final modulesAsync = ref.watch(allModulesProvider);

    return tenantAsync.when(
      data: (detail) {
        _initFromBilling(detail?.billingInfo);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBillingForm(context),
              const SizedBox(height: 24),
              _buildSubscriptionSection(
                context,
                ref,
                activeKeysAsync,
                modulesAsync,
              ),
              // TODO: MVP fáze - Seznam faktur je skrytý, dokud nebude hotový Super-Admin fakturační modul.
              // const SizedBox(height: 24),
              // _buildInvoicesSection(context),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'common.error_with_message'.tr(namedArgs: {'message': e.toString()}),
          style: TextStyle(color: Colors.red.shade700),
        ),
      ),
    );
  }

  /// Formulář fakturačních údajů – Firma, IČO, DIČ, adresa, kontakt.
  Widget _buildBillingForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'super_admin.billing_details_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[900],
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'super_admin.billing_company_name'.tr(),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'super_admin.billing_ico'.tr(),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _icoController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'super_admin.billing_dic'.tr(),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _dicController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'super_admin.billing_street'.tr(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _streetController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'super_admin.billing_city'.tr(),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'super_admin.billing_zip'.tr(),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _zipController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'super_admin.billing_country'.tr(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _countryController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'super_admin.billing_contact_email'.tr(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _contactEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'super_admin.billing_phone'.tr(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_dirty && !_saving) ? _saveBilling : null,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text('super_admin.btn_save_billing'.tr()),
          ),
        ],
      ),
    );
  }

  /// Sekce „Moje předplatné“ – Marketplace mřížka VŠECH modulů s rozlišením aktivní/neaktivní.
  /// Iterujeme přes celý katalog modulů; u každého dynamicky zjišťujeme isActive z tenant_modules.
  Widget _buildSubscriptionSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Set<String>> activeKeysAsync,
    AsyncValue<List<ModuleModel>> modulesAsync,
  ) {
    final activeKeys = activeKeysAsync.valueOrNull ?? {};
    final modules = modulesAsync.valueOrNull ?? [];
    final displayCurrency =
        ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'settings.billing_my_subscription'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[900],
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          if (modules.isEmpty)
            Text(
              'common.none'.tr(),
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            LayoutBuilder(
              builder: (_, constraints) {
                const crossAxisCount = 3;
                const spacing = 12.0;
                final width =
                    (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                        crossAxisCount;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: modules.map((module) {
                    final baseActive = activeKeys.contains(module.key);
                    final isActive = _pendingToggles.containsKey(module.id)
                        ? _pendingToggles[module.id]!
                        : baseActive;
                    final isToggling = _togglingModuleId == module.id;
                    final priceStr = module.price != null && currencies.isNotEmpty
                        ? CurrencyService.formatPrice(
                            module.price!.toDouble(),
                            displayCurrency,
                            currencies,
                          )
                        : (module.price != null
                            ? '${module.price!.toStringAsFixed(2)} €'
                            : '—');
                    return SizedBox(
                      width: width,
                      child: _BillingModuleCard(
                        module: module,
                        isActive: isActive,
                        isToggling: isToggling,
                        priceStr: priceStr,
                        onModuleToggle: () => _onModuleToggle(module, isActive),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('settings.billing_stripe_portal_toast'.tr()),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.payment),
            label: Text('settings.billing_manage_subscription_btn'.tr()),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Reálné přepnutí modulu – zapne/vypne v DB, včetně kontroly závislostí.
  /// Při zapínání sub-modulu bez aktivního rodiče nabídne aktivaci obou.
  /// Při vypínání hlavního modulu s aktivními sub-moduly nabídne kaskádové vypnutí.
  Future<void> _onModuleToggle(ModuleModel module, bool currentlyActive) async {
    if (_togglingModuleId != null) return;
    final tenantId = ref.read(authNotifierProvider).tenantIdForData;
    if (tenantId == null || tenantId.isEmpty) return;

    final newValue = !currentlyActive;
    final modules = ref.read(allModulesProvider).valueOrNull ?? [];
    final activeIds = ref.read(tenantActiveModuleIdsProvider(tenantId)).valueOrNull ?? {};

    // Při zapínání sub-modulu: pokud rodič není aktivní, nabídnout aktivaci obou.
    if (newValue &&
        module.parentModuleKey != null &&
        module.parentModuleKey!.isNotEmpty) {
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
        await _activateBothModules(tenantId, parent, module);
        return;
      }
    }

    // Při vypínání hlavního modulu: pokud má aktivní sub-moduly, nabídnout kaskádové vypnutí.
    if (!newValue) {
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
        await _deactivateCascade(tenantId, module, activeDependents);
        return;
      }
    }

    setState(() {
      _pendingToggles[module.id] = newValue;
      _togglingModuleId = module.id;
    });
    try {
      await SuperAdminService.toggleModule(tenantId, module.id, newValue);
      if (newValue) {
        await AuditLogService.log(
          tenantId: tenantId,
          userId: SupabaseService.client.auth.currentUser?.id,
          actionType: 'MODULE_ACTIVATED',
          tableName: 'tenant_modules',
          recordId: module.id,
          details: {'module_key': module.key},
        );
      } else {
        await AuditLogService.log(
          tenantId: tenantId,
          userId: SupabaseService.client.auth.currentUser?.id,
          actionType: 'MODULE_DEACTIVATED',
          tableName: 'tenant_modules',
          recordId: module.id,
          details: {'module_key': module.key},
        );
      }
      if (!mounted) return;
      ref.invalidate(activeModuleKeysProvider);
      ref.invalidate(tenantActiveModuleIdsProvider(tenantId));
      setState(() {
        _pendingToggles.remove(module.id);
        _togglingModuleId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue
                  ? 'super_admin.module_enabled'.tr(namedArgs: {'name': ModuleIconMapper.getLabelKey(module.key).tr()})
                  : 'super_admin.module_disabled'.tr(namedArgs: {'name': ModuleIconMapper.getLabelKey(module.key).tr()}),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  /// Dialog závislosti sub-modulu – rodič musí být aktivní. Nabídne aktivaci obou.
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

  /// Dialog před kaskádovým vypnutím hlavního modulu a jeho sub-modulů.
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

  /// Aktivuje rodičovský modul a sub-modul.
  Future<void> _activateBothModules(
    String tenantId,
    ModuleModel parent,
    ModuleModel subModule,
  ) async {
    setState(() {
      _pendingToggles[parent.id] = true;
      _pendingToggles[subModule.id] = true;
      _togglingModuleId = subModule.id;
    });
    try {
      await SuperAdminService.toggleModule(tenantId, parent.id, true);
      await AuditLogService.log(
        tenantId: tenantId,
        userId: SupabaseService.client.auth.currentUser?.id,
        actionType: 'MODULE_ACTIVATED',
        tableName: 'tenant_modules',
        recordId: parent.id,
        details: {'module_key': parent.key},
      );
      await SuperAdminService.toggleModule(tenantId, subModule.id, true);
      await AuditLogService.log(
        tenantId: tenantId,
        userId: SupabaseService.client.auth.currentUser?.id,
        actionType: 'MODULE_ACTIVATED',
        tableName: 'tenant_modules',
        recordId: subModule.id,
        details: {'module_key': subModule.key},
      );
      if (!mounted) return;
      ref.invalidate(activeModuleKeysProvider);
      ref.invalidate(tenantActiveModuleIdsProvider(tenantId));
      setState(() {
        _pendingToggles.remove(parent.id);
        _pendingToggles.remove(subModule.id);
        _togglingModuleId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('super_admin.module_enabled'.tr(namedArgs: {'name': ModuleIconMapper.getLabelKey(subModule.key).tr()})),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  /// Vypne hlavní modul a všechny aktivní sub-moduly.
  Future<void> _deactivateCascade(
    String tenantId,
    ModuleModel mainModule,
    List<ModuleModel> activeDependents,
  ) async {
    final toDeactivate = [mainModule, ...activeDependents];
    for (final m in toDeactivate) {
      setState(() {
        _pendingToggles[m.id] = false;
        _togglingModuleId = m.id;
      });
    }
    try {
      for (final m in toDeactivate) {
        await SuperAdminService.toggleModule(tenantId, m.id, false);
        await AuditLogService.log(
          tenantId: tenantId,
          userId: SupabaseService.client.auth.currentUser?.id,
          actionType: 'MODULE_DEACTIVATED',
          tableName: 'tenant_modules',
          recordId: m.id,
          details: {'module_key': m.key},
        );
      }
      if (!mounted) return;
      ref.invalidate(activeModuleKeysProvider);
      ref.invalidate(tenantActiveModuleIdsProvider(tenantId));
      for (final m in toDeactivate) {
        setState(() => _pendingToggles.remove(m.id));
      }
      setState(() => _togglingModuleId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('super_admin.module_disabled'.tr(namedArgs: {'name': ModuleIconMapper.getLabelKey(mainModule.key).tr()})),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  /// Sekce „Moje faktury“ – mock položky (2–3 statické).
  /// TODO: MVP fáze - Seznam faktur je skrytý, dokud nebude hotový Super-Admin fakturační modul.
  // ignore: unused_element
  Widget _buildInvoicesSection(BuildContext context) {
    const mockItems = [
      ('INV-2026-001', 2026, 3, 1, '€ 150'),
      ('INV-2026-002', 2026, 2, 15, '€ 200'),
      ('INV-2026-003', 2026, 1, 1, '€ 100'),
    ];
    final locale = context.locale.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'settings.billing_my_invoices'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[900],
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: mockItems.length,
          itemBuilder: (context, index) {
            final (number, y, m, d, amount) = mockItems[index];
            final dateStr = DateFormat.yMMMMd(locale).format(DateTime(y, m, d));
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('super_admin.invoice_item_title'.tr(namedArgs: {'number': number})),
                subtitle: Text(
                  'super_admin.invoice_paid_date'.tr(namedArgs: {'date': dateStr}),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(amount, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.download,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Karta modulu v sekci Moje předplatné – vizuálně klon z TenantCommandModal.
/// Bílý kontejner, zaoblení 16, jemný stín. Ikona, název, cena + typ účtování, Switch.
/// NEAKTIVNÍ moduly mají opacity 0.6. Bez ikony nastavení a bez textu o zkušební době.
class _BillingModuleCard extends StatelessWidget {
  const _BillingModuleCard({
    required this.module,
    required this.isActive,
    required this.isToggling,
    required this.priceStr,
    required this.onModuleToggle,
  });

  final ModuleModel module;
  final bool isActive;
  final bool isToggling;
  final String priceStr;
  final VoidCallback onModuleToggle;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (isToggling)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  ModuleIconMapper.getIcon(module.key),
                  size: 28,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              const Spacer(),
              Switch(
                value: isActive,
                onChanged: isToggling ? null : (_) => onModuleToggle(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ModuleIconMapper.getLabelKey(module.key).tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.grey[900] : Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            priceStr,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.grey[700] : Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            getPricingTypeLabelKey(module.pricingType).tr(),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return isActive
        ? content
        : Opacity(
            opacity: 0.6,
            child: content,
          );
  }
}
