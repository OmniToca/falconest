import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/audit_log_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/module_model.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/current_tenant_name_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/utils/module_icon_mapper.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/super_admin/module_subscription_dialog.dart';
import 'package:falconest/features/super_admin/providers/dashboard_mrr_provider.dart';
import 'package:falconest/features/super_admin/providers/tenant_detail_provider.dart';
import 'package:falconest/features/super_admin/services/super_admin_service.dart';
import 'package:falconest/features/super_admin/utils/price_format_helper.dart';

/// Obrazovka detailu agentury (CRM karta) – Info & Fakturace, Moduly & Plán, Tým & Statistiky.
class TenantDetailScreen extends ConsumerStatefulWidget {
  const TenantDetailScreen({super.key, required this.tenantId});

  final String tenantId;

  @override
  ConsumerState<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends ConsumerState<TenantDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _notesController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _icoController = TextEditingController();
  final _dicController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _countryController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _billingDirty = false;
  bool _notesDirty = false;
  bool _savingBilling = false;
  bool _billingInitialized = false;
  bool _notesInitialized = false;
  String _currency = 'CZK';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    void markBillingDirty() => setState(() => _billingDirty = true);
    void markNotesDirty() => setState(() => _notesDirty = true);
    _companyNameController.addListener(markBillingDirty);
    _icoController.addListener(markBillingDirty);
    _dicController.addListener(markBillingDirty);
    _streetController.addListener(markBillingDirty);
    _cityController.addListener(markBillingDirty);
    _zipController.addListener(markBillingDirty);
    _countryController.addListener(markBillingDirty);
    _contactEmailController.addListener(markBillingDirty);
    _phoneController.addListener(markBillingDirty);
    _notesController.addListener(markNotesDirty);
  }

  @override
  void didUpdateWidget(TenantDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenantId != widget.tenantId) {
      _billingInitialized = false;
      _notesInitialized = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
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

  void _initBilling(BillingInfo? info, String? currency) {
    if (_billingInitialized) return;
    _billingInitialized = true;
    _currency = currency ?? 'CZK';
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

  void _initNotes(String? notes) {
    if (_notesInitialized) return;
    _notesInitialized = true;
    _notesController.text = notes ?? '';
  }

  Future<void> _saveBillingAndNotes() async {
    if ((!_billingDirty && !_notesDirty) || _savingBilling) return;
    setState(() => _savingBilling = true);
    try {
      final billing = BillingInfo(
        companyName: _companyNameController.text.trim().isEmpty ? null : _companyNameController.text.trim(),
        ico: _icoController.text.trim().isEmpty ? null : _icoController.text.trim(),
        dic: _dicController.text.trim().isEmpty ? null : _dicController.text.trim(),
        street: _streetController.text.trim().isEmpty ? null : _streetController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        zip: _zipController.text.trim().isEmpty ? null : _zipController.text.trim(),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        contactEmail: _contactEmailController.text.trim().isEmpty ? null : _contactEmailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      );
      await SupabaseService.client
          .from('tenants')
          .update({
            'billing_info': billing.toJson(),
            'notes': _notesController.text.trim(),
            'currency': _currency,
          })
          .eq('id', widget.tenantId);

      if (!mounted) return;
      ref.invalidate(tenantDetailProvider(widget.tenantId));
      setState(() {
        _billingDirty = false;
        _notesDirty = false;
        _savingBilling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.billing_saved'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingBilling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'common.error'.tr()}: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Formátuje MRR pro záložku Info & Fakturace (per-tenant EUR → zobrazení v měně admina).
  String _formatMrrForTab(double? eur, List<CurrencyRow> currencies, String displayCurrency) {
    if (eur == null) return '—';
    return CurrencyService.formatPrice(eur, displayCurrency, currencies);
  }

  Future<void> _onImpersonate(String tenantName) async {
    try {
      await ref.read(authNotifierProvider).impersonateTenant(widget.tenantId);
      if (!mounted) return;
      ref.invalidate(tenantDetailProvider(widget.tenantId));
      ref.invalidate(adminTasksProvider);
      ref.invalidate(adminReservationsProvider);
      ref.invalidate(apartmentsProvider);
      ref.invalidate(adminTeamProvider);
      ref.invalidate(staffAbsencesProvider);
      ref.invalidate(currentTenantNameProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.impersonate_success'.tr(namedArgs: {'name': tenantName})),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(tenantDetailProvider(widget.tenantId));
    final profilesAsync = ref.watch(tenantProfilesProvider(widget.tenantId));
    final statsAsync = ref.watch(tenantStatsProvider(widget.tenantId));
    final mrrAsync = ref.watch(dashboardMrrProvider);
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
    final displayCurrency = ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';

    return detailAsync.when(
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(title: Text('common.error'.tr())),
            body: const Center(child: Text('Agentura nenalezena')),
          );
        }
        _initBilling(detail.billingInfo, detail.currency);
        _initNotes(detail.notes);

        return Scaffold(
          appBar: AppBar(
            title: Text(detail.name),
            actions: [
              FilledButton.icon(
                onPressed: () => _onImpersonate(detail.name),
                icon: const Icon(Icons.login, size: 20),
                label: Text('super_admin.impersonate'.tr()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'super_admin.section_info_billing'.tr()),
                Tab(text: 'super_admin.section_modules_plan'.tr()),
                Tab(text: 'super_admin.section_team_stats'.tr()),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _InfoBillingTab(
                companyName: _companyNameController,
                ico: _icoController,
                dic: _dicController,
                street: _streetController,
                city: _cityController,
                zip: _zipController,
                country: _countryController,
                contactEmail: _contactEmailController,
                phone: _phoneController,
                notes: _notesController,
                currency: _currency,
                onCurrencyChanged: (v) => setState(() { _currency = v; _billingDirty = true; }),
                onSave: _saveBillingAndNotes,
                saving: _savingBilling,
                dirty: _billingDirty || _notesDirty,
                mrrFormatted: _formatMrrForTab(mrrAsync.valueOrNull?.perTenantEur[widget.tenantId], currencies, displayCurrency),
                stripeCustomerId: detail.stripeCustomerId,
              ),
              _ModulesPlanTab(
                tenantId: widget.tenantId,
                pricePerApartment: detail.pricePerApartment,
                currency: _currency,
                discountPercentage: detail.discountPercentage,
              ),
              _TeamStatsTab(profilesAsync: profilesAsync, statsAsync: statsAsync),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text('super_admin.section_info_billing'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text('common.error'.tr())),
        body: Center(child: Text('$e')),
      ),
    );
  }
}

/// Tab 1: Info & Fakturace – formulář fakturačních údajů + měna + interní poznámky.
class _InfoBillingTab extends StatelessWidget {
  const _InfoBillingTab({
    required this.companyName,
    required this.ico,
    required this.dic,
    required this.street,
    required this.city,
    required this.zip,
    required this.country,
    required this.contactEmail,
    required this.phone,
    required this.notes,
    required this.currency,
    required this.onCurrencyChanged,
    required this.onSave,
    required this.saving,
    required this.dirty,
    required this.mrrFormatted,
    required this.stripeCustomerId,
  });

  final TextEditingController companyName;
  final TextEditingController ico;
  final TextEditingController dic;
  final TextEditingController street;
  final TextEditingController city;
  final TextEditingController zip;
  final TextEditingController country;
  final TextEditingController contactEmail;
  final TextEditingController phone;
  final TextEditingController notes;
  final String currency;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onSave;
  final bool saving;
  final bool dirty;
  final String mrrFormatted;
  final String? stripeCustomerId;

  static const List<String> _currencies = ['CZK', 'EUR', 'USD'];

  /// Sekce A: Finanční přehled – MRR a stav Stripe (dvě karty).
  Widget _buildFinancialCards(BuildContext context) {
    final isActive = stripeCustomerId != null && stripeCustomerId!.isNotEmpty;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'super_admin.mrr_monthly_revenue'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                mrrFormatted,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        _buildCard(
          context: context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'super_admin.stripe_status_title'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: isActive ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isActive
                        ? 'super_admin.stripe_status_active'.tr()
                        : 'super_admin.stripe_status_not_connected'.tr(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required BuildContext context, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sekce A: Finanční přehled
          _buildFinancialCards(context),
          const SizedBox(height: 24),
          // Sekce B: Fakturační údaje
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'super_admin.billing_details_title'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                Text(
                  'super_admin.billing_currency'.tr(),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _currencies.contains(currency) ? currency : 'CZK',
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _currencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onCurrencyChanged(v);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'super_admin.billing_company_name'.tr(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: companyName,
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
                          Text('super_admin.billing_ico'.tr(), style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(height: 4),
                          TextField(controller: ico, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('super_admin.billing_dic'.tr(), style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(height: 4),
                          TextField(controller: dic, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('super_admin.billing_street'.tr(), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                TextField(controller: street, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('super_admin.billing_city'.tr(), style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(height: 4),
                          TextField(controller: city, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('super_admin.billing_zip'.tr(), style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(height: 4),
                          TextField(controller: zip, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('super_admin.billing_country'.tr(), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                TextField(controller: country, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                const SizedBox(height: 12),
                Text('super_admin.billing_contact_email'.tr(), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                TextField(
                  controller: contactEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                Text('super_admin.billing_phone'.tr(), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('super_admin.billing_internal_notes'.tr(), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: notes,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (dirty && !saving) ? onSave : null,
          icon: saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text('super_admin.btn_save_billing'.tr()),
        ),
        // Sekce C: Poslední faktury (UI placeholder – mock data)
        const SizedBox(height: 24),
        Text(
          'super_admin.invoices_last_title'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _buildMockInvoicesList(context),
      ],
    ),
  );
  }

  /// UI placeholder – tři mock faktury pro vizuální představu historie.
  Widget _buildMockInvoicesList(BuildContext context) {
    const mockItems = [
      ('INV-2026-001', 2026, 3, 1, '€ 150'),
      ('INV-2026-002', 2026, 2, 15, '€ 200'),
      ('INV-2026-003', 2026, 1, 1, '€ 100'),
    ];
    final locale = context.locale.toString();
    return ListView.builder(
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
            leading: const Icon(Icons.receipt_long),
            title: Text('super_admin.invoice_item_title'.tr(namedArgs: {'number': number})),
            subtitle: Text('super_admin.invoice_paid_date'.tr(namedArgs: {'date': dateStr})),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(amount, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                Icon(Icons.download, size: 20, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tab 2: Moduly & Plán – přepínače modulů + ceny (fixed / per_apartment / per_user) + MRR.
class _ModulesPlanTab extends ConsumerStatefulWidget {
  const _ModulesPlanTab({
    required this.tenantId,
    this.pricePerApartment,
    this.currency = 'CZK',
    this.discountPercentage = 0,
  });

  final String tenantId;
  final num? pricePerApartment;
  final String currency;
  final int discountPercentage;

  @override
  ConsumerState<_ModulesPlanTab> createState() => _ModulesPlanTabState();
}

class _ModulesPlanTabState extends ConsumerState<_ModulesPlanTab> {
  final Map<String, bool> _pending = {};
  String? _togglingModuleId;

  Future<void> _onToggle(ModuleModel module, bool newValue) async {
    if (_togglingModuleId != null) return;

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
      _pending[module.id] = newValue;
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
        _pending.remove(module.id);
        _togglingModuleId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? 'super_admin.module_enabled'.tr(namedArgs: {'name': _label(module)})
                : 'super_admin.module_disabled'.tr(namedArgs: {'name': _label(module)}),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[TenantDetailScreen] toggleModule failed: $e');
        debugPrint('[TenantDetailScreen] stack: $st');
      }
      if (!mounted) return;
      setState(() {
        _pending.remove(module.id);
        _togglingModuleId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.module_toggle_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Zobrazí dialog závislosti sub-modulu. Vrací true pokud uživatel zvolil „Zapnout oba“.
  Future<bool?> _showSubmoduleDependencyDialog(
    BuildContext context,
    ModuleModel subModule,
    ModuleModel parentModule,
  ) {
    return showDialog<bool>(
      context: context,
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

  /// Aktivuje hlavní modul a sub-modul a zapíše audit pro oba.
  Future<void> _activateBothModules(ModuleModel parent, ModuleModel subModule) async {
    setState(() {
      _pending[parent.id] = true;
      _pending[subModule.id] = true;
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
        _pending.remove(parent.id);
        _pending.remove(subModule.id);
        _togglingModuleId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.module_enabled'.tr(namedArgs: {'name': _label(subModule)})),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[TenantDetailScreen] _activateBothModules failed: $e');
        debugPrint('[TenantDetailScreen] stack: $st');
      }
      if (!mounted) return;
      setState(() {
        _pending.remove(parent.id);
        _pending.remove(subModule.id);
        _togglingModuleId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.module_toggle_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Dialog před kaskádovým vypnutím hlavního modulu a jeho aktivních sub-modulů.
  Future<bool?> _showDeactivateCascadeDialog(
    BuildContext context,
    ModuleModel mainModule,
    List<ModuleModel> activeDependents,
  ) {
    return showDialog<bool>(
      context: context,
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
        _pending[m.id] = false;
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
        setState(() {
          _pending.remove(m.id);
        });
      }
      setState(() => _togglingModuleId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.module_disabled'.tr(namedArgs: {'name': _label(mainModule)})),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[TenantDetailScreen] _deactivateCascade failed: $e');
        debugPrint('[TenantDetailScreen] stack: $st');
      }
      if (!mounted) return;
      for (final m in toDeactivate) {
        setState(() => _pending.remove(m.id));
      }
      setState(() => _togglingModuleId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.module_toggle_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _label(ModuleModel module) => ModuleIconMapper.getLabelKey(module.key).tr();

  String _formatTrialDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  /// Otevře dialog Marketing & Předplatné pro aktivní modul; po uložení dialog sám invaliduje provider.
  Future<void> _openModuleSubscriptionDialog(ModuleModel module, TenantModuleSubscriptionData? sub) async {
    await ModuleSubscriptionDialog.show(
      context,
      tenantId: widget.tenantId,
      module: module,
      initialIsTrial: sub?.isTrial ?? false,
      initialTrialEndsAt: sub?.trialEndsAt,
      initialValidUntil: sub?.validUntil,
    );
  }

  String _currencyCode() => widget.currency.isNotEmpty ? widget.currency : 'CZK';

  /// Vrátí měsíční částku za modul v EUR podle pricingType a počtů (apartments, users).
  double _moduleMonthlyAmountEur(ModuleModel m, int apartmentCount, int userCount) {
    final priceEur = m.price?.toDouble() ?? 0;
    switch (m.pricingType) {
      case 'per_apartment':
        return priceEur * apartmentCount;
      case 'per_user':
        return priceEur * userCount;
      default:
        return priceEur;
    }
  }

  /// Text pro řádek modulu: ceny v měně tenanta (přepočet z EUR). Fixed = "250 Kč / month", atd.
  String _priceDisplay(
    ModuleModel module,
    int apartmentCount,
    int userCount,
    List<CurrencyRow> currencies,
  ) {
    if (module.price == null) return 'super_admin.module_price_na'.tr();
    final code = _currencyCode();
    final amountEur = module.price!.toDouble();
    if (currencies.isEmpty) {
      return '${amountEur.toStringAsFixed(2)} € / ${'super_admin.per_month'.tr()}';
    }
    final unitStr = CurrencyService.formatPrice(amountEur, code, currencies);
    switch (module.pricingType) {
      case 'per_apartment':
        final totalEur = amountEur * apartmentCount;
        final totalStr = CurrencyService.formatPrice(totalEur, code, currencies);
        return '$unitStr × $apartmentCount ${'super_admin.units_apartments'.tr()} = $totalStr / ${'super_admin.per_month'.tr()}';
      case 'per_user':
        final totalEur = amountEur * userCount;
        final totalStr = CurrencyService.formatPrice(totalEur, code, currencies);
        return '$unitStr × $userCount ${'super_admin.units_users'.tr()} = $totalStr / ${'super_admin.per_month'.tr()}';
      default:
        return '$unitStr / ${'super_admin.per_month'.tr()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(allModulesProvider);
    final activeAsync = ref.watch(tenantActiveModuleIdsProvider(widget.tenantId));
    final statsAsync = ref.watch(tenantStatsProvider(widget.tenantId));
    final profilesAsync = ref.watch(tenantProfilesProvider(widget.tenantId));
    final currenciesAsync = ref.watch(currenciesProvider);

    return modulesAsync.when(
      data: (modules) {
        if (modules.isEmpty) {
          return Center(
            child: Text('super_admin.module_list_empty'.tr(), style: Theme.of(context).textTheme.bodyLarge),
          );
        }
        final subscriptionMap = ref.watch(tenantModuleSubscriptionMapProvider(widget.tenantId)).valueOrNull ?? {};
        return activeAsync.when(
          data: (activeIds) {
            final apartmentCount = statsAsync.valueOrNull?.apartmentCount ?? 0;
            final userCount = profilesAsync.valueOrNull?.length ?? 0;
            final pricePerApt = widget.pricePerApartment ?? 0;
            final code = _currencyCode();
            final currencies = currenciesAsync.valueOrNull ?? [];
            final discountPct = widget.discountPercentage.clamp(0, 100);

            // MRR: pouze aktivní moduly, které NEJSOU v trialu (is_trial != true).
            double activeCostEur = 0;
            for (var i = 0; i < modules.length; i++) {
              final m = modules[i];
              final isOn = _pending.containsKey(m.id) ? _pending[m.id]! : activeIds.contains(m.id);
              final isTrial = subscriptionMap[m.id]?.isTrial == true;
              if (isOn && !isTrial) {
                activeCostEur += _moduleMonthlyAmountEur(m, apartmentCount, userCount);
              }
            }
            final baseSubscription = (pricePerApt * apartmentCount).toDouble();
            final modulesInTarget = currencies.isEmpty ? activeCostEur : CurrencyService.convert(activeCostEur, code, currencies);
            final subtotalInTarget = modulesInTarget + baseSubscription;
            final totalMonthlyInTarget = subtotalInTarget * (1 - (discountPct / 100));

            String activeCostStr;
            String baseStr;
            String totalStr;
            if (currencies.isEmpty) {
              activeCostStr = formatPrice(activeCostEur, code);
              baseStr = formatPrice(baseSubscription, code);
              totalStr = formatPrice(totalMonthlyInTarget, code);
            } else {
              activeCostStr = CurrencyService.formatPrice(activeCostEur, code, currencies);
              baseStr = CurrencyService.formatAmountInTargetCurrency(baseSubscription, code, currencies);
              totalStr = CurrencyService.formatAmountInTargetCurrency(totalMonthlyInTarget, code, currencies);
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'super_admin.mrr_active_modules'.tr(namedArgs: {'amount': activeCostStr}),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'super_admin.mrr_base_subscription'.tr(namedArgs: {'amount': baseStr}),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const Divider(height: 24),
                        Text(
                          'super_admin.mrr_total_monthly'.tr(namedArgs: {'amount': totalStr}),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        if (discountPct > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'super_admin.mrr_discount_applied'.tr(namedArgs: {'percent': '$discountPct'}),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'super_admin.module_management_hint'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                ...modules.map((module) {
                  final isEnabled = _pending.containsKey(module.id)
                      ? _pending[module.id]!
                      : activeIds.contains(module.id);
                  final isToggling = _togglingModuleId == module.id;
                  final sub = subscriptionMap[module.id];
                  final trialBadge = (sub != null && sub.isTrial && sub.trialEndsAt != null)
                      ? 'super_admin.module_trial_badge'.tr(namedArgs: {'date': _formatTrialDate(sub.trialEndsAt!)})
                      : null;
                  final cardHeight = trialBadge != null ? 100.0 : 72.0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      height: cardHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 72,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16, right: 48),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (isToggling)
                                            const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          else
                                            Icon(
                                              ModuleIconMapper.getIcon(module.key),
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _label(module),
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            _priceDisplay(module, apartmentCount, userCount, currencies),
                                            style: Theme.of(context).textTheme.bodySmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: isEnabled,
                                    onChanged: isToggling ? null : (value) => _onToggle(module, value),
                                  ),
                                ],
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
                                  trialBadge,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ),
                          if (isEnabled)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: const Icon(Icons.settings),
                                iconSize: 18,
                                color: Colors.grey,
                                onPressed: () => _openModuleSubscriptionDialog(module, sub),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

/// Tab 3: Tým & Statistiky – uživatelé + počty bytů a rezervací.
class _TeamStatsTab extends StatelessWidget {
  const _TeamStatsTab({
    required this.profilesAsync,
    required this.statsAsync,
  });

  final AsyncValue<List<ProfileRow>> profilesAsync;
  final AsyncValue<TenantStats> statsAsync;

  @override
  Widget build(BuildContext context) {
    final stats = statsAsync.valueOrNull;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.apartment, size: 32, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        '${stats?.apartmentCount ?? 0}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'super_admin.stats_apartments_managed'.tr(),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.calendar_month, size: 32, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        '${stats?.reservationsThisMonth ?? 0}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'super_admin.stats_reservations_this_month'.tr(),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'super_admin.section_team'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        profilesAsync.when(
          data: (profiles) {
            if (profiles.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'super_admin.team_empty'.tr(),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: profiles
                  .map(
                    (p) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
                        ),
                        title: Text(p.name),
                        subtitle: Text(p.role),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        ),
      ],
    );
  }
}
