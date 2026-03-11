import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
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
import 'package:falconest/features/super_admin/providers/all_tenants_provider.dart';
import 'package:falconest/features/super_admin/providers/dashboard_mrr_provider.dart';
import 'package:falconest/features/super_admin/providers/hq_staff_provider.dart';
import 'package:falconest/features/super_admin/providers/tenant_detail_provider.dart';
import 'package:falconest/features/super_admin/services/onboarding_export_service.dart';
import 'package:falconest/features/super_admin/services/super_admin_service.dart';
import 'package:falconest/core/utils/app_modal_utils.dart';
import 'package:falconest/features/super_admin/utils/price_format_helper.dart';

/// Modální dialog s plným detailem agentury – Info & Fakturace, Moduly & Plán, Tým & Statistiky.
/// Z menu / dashboard volat TenantDetailModal.show(context, tenantId) místo context.push.
class TenantDetailModal {
  TenantDetailModal._();

  /// Otevře Detail agentury jako modální dialog (blur, centrované okno). Stejný vizuál jako SettingsModal.
  /// Používá [showAppModal] pro jednotný vizuál napříč aplikací.
  static Future<void> show(BuildContext hostContext, String tenantId, {String? tenantName}) {
    return showAppModal<void>(
      context: hostContext,
      barrierLabel: 'super_admin.barrier_detail'.tr(),
      maxWidth: 900,
      maxHeightFraction: 0.88,
      child: TenantDetailScreen(tenantId: tenantId, isModal: true),
    );
  }
}

/// Obrazovka detailu agentury (CRM karta) – Info & Fakturace, Moduly & Plán, Tým & Statistiky.
class TenantDetailScreen extends ConsumerStatefulWidget {
  const TenantDetailScreen({super.key, required this.tenantId, this.isModal = false});

  final String tenantId;
  /// True = zobrazen jako modal (vlastní hlavička s křížkem), false = plná stránka s AppBar.
  final bool isModal;

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
  final _discountController = TextEditingController();

  bool _billingDirty = false;
  bool _notesDirty = false;
  bool _savingBilling = false;
  bool _billingInitialized = false;
  bool _notesInitialized = false;
  String _currency = 'CZK';
  bool _isExporting = false;

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
    _discountController.addListener(markBillingDirty);
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
    _discountController.dispose();
    super.dispose();
  }

  void _initBilling(BillingInfo? info, String? currency, int discountPercentage) {
    if (_billingInitialized) return;
    _billingInitialized = true;
    _currency = currency ?? 'CZK';
    _discountController.text = '$discountPercentage';
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
      final discountStr = _discountController.text.trim();
      final discountPct = discountStr.isEmpty ? 0 : (int.tryParse(discountStr) ?? 0).clamp(0, 100);

      await SupabaseService.client
          .from('tenants')
          .update({
            'billing_info': billing.toJson(),
            'notes': _notesController.text.trim(),
            'currency': _currency,
            'discount_percentage': discountPct,
          })
          .eq('id', widget.tenantId);

      if (!mounted) return;
      ref.invalidate(tenantDetailProvider(widget.tenantId));
      ref.invalidate(dashboardMrrProvider);
      ref.invalidate(tenantsWithStatusProvider);
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
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          elevation: 10,
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
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          elevation: 10,
        ),
      );
    }
  }

  /// Exportuje data agentury do Master Excel šablony (1:1 kompatibilita s importem).
  Future<void> _onExport(String tenantName) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      await OnboardingExportService.exportTenantData(widget.tenantId, tenantName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.export_success'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          elevation: 10,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.export_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          elevation: 10,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Hlavička modalu – stejný styl jako SettingsModal: název vlevo, Převtělit + křížek vpravo.
  Widget _buildModalHeader(BuildContext context, String tenantName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tenantName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isExporting ? null : () => _onExport(tenantName),
            icon: _isExporting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download, size: 18),
            label: Text('super_admin.export_data'.tr()),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/super-admin/tenant/${widget.tenantId}/onboarding'),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text('super_admin.onboarding_wizard_btn'.tr()),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _onImpersonate(tenantName),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: Text('super_admin.impersonate'.tr()),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'common.cancel'.tr(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
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
      ref.invalidate(apartmentsFullListProvider);
      ref.invalidate(adminTeamProvider);
      ref.invalidate(teamFullListProvider);
      ref.invalidate(staffAbsencesProvider);
      ref.invalidate(currentTenantNameProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.impersonate_success'.tr(namedArgs: {'name': tenantName})),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          elevation: 10,
        ),
      );
      if (widget.isModal) Navigator.of(context).pop();
      context.go('/admin');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.impersonate_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          elevation: 10,
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
          return widget.isModal
              ? Center(child: Text('super_admin.tenant_not_found'.tr()))
              : Scaffold(
                  appBar: AppBar(title: Text('common.error'.tr())),
                  body: Center(child: Text('super_admin.tenant_not_found'.tr())),
                );
        }
        _initBilling(detail.billingInfo, detail.currency, detail.discountPercentage);
        _initNotes(detail.notes);

        final tabBar = TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(text: 'super_admin.section_info_billing'.tr()),
            Tab(text: 'super_admin.section_modules_plan'.tr()),
            Tab(text: 'super_admin.section_team_stats'.tr()),
          ],
        );

        final tabBarView = TabBarView(
          controller: _tabController,
          children: [
            _InfoBillingTab(
              tenantId: widget.tenantId,
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
              discount: _discountController,
              currency: _currency,
              onCurrencyChanged: (v) => setState(() { _currency = v; _billingDirty = true; }),
              onSave: _saveBillingAndNotes,
              saving: _savingBilling,
              dirty: _billingDirty || _notesDirty,
              mrrFormatted: _formatMrrForTab(mrrAsync.valueOrNull?.perTenantEur[widget.tenantId], currencies, displayCurrency),
              stripeCustomerId: detail.stripeCustomerId,
              trialEndsAt: detail.trialEndsAt,
              paidUntil: detail.paidUntil,
              acquiredBy: detail.acquiredBy,
              managedBy: detail.managedBy,
            ),
            _ModulesPlanTab(
              tenantId: widget.tenantId,
              pricePerApartment: detail.pricePerApartment,
              currency: _currency,
              discountPercentage: detail.discountPercentage,
            ),
            _TeamStatsTab(profilesAsync: profilesAsync, statsAsync: statsAsync),
          ],
        );

        if (widget.isModal) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModalHeader(context, detail.name),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: tabBar,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  color: Colors.grey.shade50,
                  child: tabBarView,
                ),
              ),
            ],
          );
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: Text(detail.name),
            actions: [
              OutlinedButton.icon(
                onPressed: _isExporting ? null : () => _onExport(detail.name),
                icon: _isExporting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download, size: 18),
                label: Text('super_admin.export_data'.tr()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/super-admin/tenant/${widget.tenantId}/onboarding'),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text('super_admin.onboarding_wizard_btn'.tr()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
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
            bottom: tabBar,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Container(
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: tabBarView,
              ),
            ),
          ),
        );
      },
      loading: () => widget.isModal
          ? const Center(child: CircularProgressIndicator())
          : Scaffold(
              appBar: AppBar(title: Text('super_admin.section_info_billing'.tr())),
              body: const Center(child: CircularProgressIndicator()),
            ),
      error: (e, _) => widget.isModal
          ? Center(child: Text('$e'))
          : Scaffold(
              appBar: AppBar(title: Text('common.error'.tr())),
              body: Center(child: Text('$e')),
            ),
    );
  }
}

/// Tab 1: Info & Fakturace – formulář fakturačních údajů + měna + sleva + interní poznámky.
class _InfoBillingTab extends ConsumerWidget {
  const _InfoBillingTab({
    required this.tenantId,
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
    required this.discount,
    required this.currency,
    required this.onCurrencyChanged,
    required this.onSave,
    required this.saving,
    required this.dirty,
    required this.mrrFormatted,
    required this.stripeCustomerId,
    required this.trialEndsAt,
    required this.paidUntil,
    this.acquiredBy,
    this.managedBy,
  });

  final String tenantId;
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
  final TextEditingController discount;
  final String currency;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onSave;
  final bool saving;
  final bool dirty;
  final String mrrFormatted;
  final String? stripeCustomerId;
  final DateTime? trialEndsAt;
  final DateTime? paidUntil;
  /// Lovec – profile_id zaměstnance, který agenturu získal (tenants.acquired_by).
  final String? acquiredBy;
  /// Farmář – profile_id zaměstnance, který agenturu spravuje (tenants.managed_by).
  final String? managedBy;

  static const List<String> _currencies = ['CZK', 'EUR', 'USD'];

  /// Formátuje datum pro zobrazení (dd.MM.yyyy).
  static String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  /// Karta Zkušební doba (Trial) a Zaplaceno do (Kill Switch) – kalendář + rychlé prodloužení.
  Widget _buildTrialPaidUntilCards(BuildContext context, WidgetRef ref) {
    const trialColor = Colors.orange;
    const paidColor = Colors.teal;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Karta A: Zkušební doba
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: trialColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: trialColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 28, color: trialColor),
                  const SizedBox(height: 8),
                  Text(
                    'super_admin.billing_trial_ends'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trialEndsAt != null
                              ? _formatDate(trialEndsAt)
                              : 'super_admin.billing_not_set'.tr(),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, size: 20),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: trialEndsAt ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            await SuperAdminService.updateTenantTrialDate(tenantId, date);
                            ref.invalidate(tenantDetailProvider(tenantId));
                            ref.invalidate(tenantsWithStatusProvider);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Karta B: Zaplaceno do (Kill Switch)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: paidColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: paidColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.payment,
                    size: 28,
                    color: (paidUntil != null && paidUntil!.isBefore(DateTime.now()))
                        ? Colors.red
                        : paidColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'super_admin.billing_paid_until'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          paidUntil != null
                              ? _formatDate(paidUntil)
                              : 'super_admin.billing_not_set'.tr(),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: (paidUntil != null && paidUntil!.isBefore(DateTime.now()))
                                    ? Colors.red
                                    : null,
                                fontWeight: (paidUntil != null && paidUntil!.isBefore(DateTime.now()))
                                    ? FontWeight.w600
                                    : null,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today, size: 20),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: paidUntil ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) {
                            await SuperAdminService.updateTenantPaidUntil(tenantId, date);
                            ref.invalidate(tenantDetailProvider(tenantId));
                            ref.invalidate(tenantsWithStatusProvider);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Rychlé prodloužení přístupu po zaplacení faktury (+1 měsíc)
                  TextButton.icon(
                    onPressed: () async {
                      final base = paidUntil ?? DateTime.now();
                      final next = DateTime(base.year, base.month + 1, base.day);
                      await SuperAdminService.updateTenantPaidUntil(tenantId, next);
                      ref.invalidate(tenantDetailProvider(tenantId));
                      ref.invalidate(tenantsWithStatusProvider);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('super_admin.billing_add_month'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sekce Lovec a Farmář – dva dropdowny s HQ personálem; při změně okamžitě uloží do DB a invaliduje providery.
  Widget _buildHunterFarmerSection(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(hqStaffProvider);
    return staffAsync.when(
      data: (staff) {
        final items = [
          DropdownMenuItem<String?>(value: null, child: Text('super_admin.hunter_farmer_select_person'.tr())),
          ...staff.map((e) => DropdownMenuItem<String?>(value: e.id, child: Text(e.displayName))),
        ];
        return _sectionCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'super_admin.hunter_farmer_section_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[900],
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'super_admin.hunter_label'.tr(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String?>(
                initialValue: acquiredBy,
                decoration: _inputDecoration(),
                items: items,
                onChanged: (v) async {
                  await SuperAdminService.updateTenantAcquiredBy(tenantId, v);
                  ref.invalidate(tenantDetailProvider(tenantId));
                  ref.invalidate(tenantsWithStatusProvider);
                },
              ),
              const SizedBox(height: 16),
              Text(
                'super_admin.farmer_label'.tr(),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String?>(
                initialValue: managedBy,
                decoration: _inputDecoration(),
                items: items,
                onChanged: (v) async {
                  await SuperAdminService.updateTenantManagedBy(tenantId, v);
                  ref.invalidate(tenantDetailProvider(tenantId));
                  ref.invalidate(tenantsWithStatusProvider);
                },
              ),
            ],
          ),
        );
      },
      loading: () => _sectionCard(context, child: const Center(child: CircularProgressIndicator())),
      error: (_, _) => _sectionCard(context, child: Text('super_admin.load_error'.tr())),
    );
  }

  /// Sekce A: Finanční přehled – MRR, Stav Stripe a Sleva v řadě s IntrinsicHeight (identická výška karet).
  Widget _buildFinancialCards(BuildContext context) {
    final isActive = stripeCustomerId != null && stripeCustomerId!.isNotEmpty;
    final mrrColor = Colors.green;
    final stripeColor = isActive ? Colors.green : Colors.orange;
    const discountColor = Colors.blue;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _profileStyleCard(
              context: context,
              color: mrrColor,
              icon: Icons.attach_money_rounded,
              title: 'super_admin.mrr_monthly_revenue'.tr(),
              child: Text(
                mrrFormatted,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _profileStyleCard(
              context: context,
              color: stripeColor,
              icon: isActive ? Icons.check_circle : Icons.warning_amber_rounded,
              title: 'super_admin.stripe_status_title'.tr(),
              child: Text(
                isActive
                    ? 'super_admin.stripe_status_active'.tr()
                    : 'super_admin.stripe_status_not_connected'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: discountColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: discountColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.percent, size: 28, color: discountColor),
                  const SizedBox(height: 8),
                  Text(
                    'super_admin.discount_percentage_label'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: discount,
                    keyboardType: TextInputType.number,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      suffixText: '%',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Karta ve stylu Settings Jazyk/Měna – pastelové pozadí, ikona, výrazný okraj. Statická pro použití v dalších tabech.
  static Widget _profileStyleCard({
    required BuildContext context,
    required Color color,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  /// Kontejner sekce – přesná kopie Zabezpečení účtu (user_profile_tab: padding 20, borderRadius 16, shadow).
  static Widget _sectionCard(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: child,
    );
  }

  /// InputDecoration – přesná kopie ze Zabezpečení účtu (user_profile_tab).
  static InputDecoration _inputDecoration({String? label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sekce A: Finanční přehled
          _buildFinancialCards(context),
          const SizedBox(height: 24),
          // Sekce A2: Zkušební doba a Zaplaceno do (Trial & Kill Switch)
          _buildTrialPaidUntilCards(context, ref),
          const SizedBox(height: 24),
          // Sekce A3: Lovec a Farmář – výběr interního HQ personálu zodpovědného za agenturu (okamžité uložení + invalidace).
          _buildHunterFarmerSection(context, ref),
          const SizedBox(height: 24),
          // Sekce B: Fakturační údaje
          _sectionCard(
            context,
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
                  'super_admin.billing_currency'.tr(),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _currencies.contains(currency) ? currency : 'CZK',
                  decoration: _inputDecoration(),
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
                TextField(controller: companyName, decoration: _inputDecoration()),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('super_admin.billing_ico'.tr(), style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(height: 4),
                          TextField(controller: ico, decoration: _inputDecoration()),
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
                          TextField(controller: dic, decoration: _inputDecoration()),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('super_admin.billing_street'.tr(), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                TextField(controller: street, decoration: _inputDecoration()),
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
                          TextField(controller: city, decoration: _inputDecoration()),
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
                          TextField(controller: zip, decoration: _inputDecoration()),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('super_admin.billing_country'.tr(), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                TextField(controller: country, decoration: _inputDecoration()),
                const SizedBox(height: 12),
                Text('super_admin.billing_contact_email'.tr(), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                TextField(
                  controller: contactEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration(),
                ),
                const SizedBox(height: 12),
                Text('super_admin.billing_phone'.tr(), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        _sectionCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'super_admin.billing_internal_notes'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.grey[900],
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notes,
                maxLines: 4,
                decoration: _inputDecoration().copyWith(alignLabelWithHint: true),
              ),
            ],
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
        // Sekce C: Poslední faktury (UI placeholder – mock data) – ve stylu Settings (karta).
        const SizedBox(height: 24),
        _sectionCard(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'super_admin.invoices_last_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[900],
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              _buildMockInvoicesList(context),
            ],
          ),
        ),
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

  /// Přepínač modulů: zapnutí/vypnutí s ošetřením závislostí (parent/submoduly).
  /// Obaleno v try-catch-finally pro čitelné chybové hlášky.
  Future<void> _onToggle(ModuleModel module, bool value) async {
    if (_togglingModuleId != null) return;

    // Nastavení stavu načítání – optimistic UI
    setState(() {
      _pending[module.id] = value;
      _togglingModuleId = module.id;
    });

    try {
      final modules = ref.read(allModulesProvider).valueOrNull ?? [];
      final activeIds = ref.read(tenantActiveModuleIdsProvider(widget.tenantId)).valueOrNull ?? {};
      final cancelAtPeriodEndIds = ref.read(tenantModuleCancelAtPeriodEndIdsProvider(widget.tenantId)).valueOrNull ?? {};

      // Kliknutí na modul s cancel_at_period_end = zrušení výpovědi (modul zůstane aktivní).
      if (!value && cancelAtPeriodEndIds.contains(module.id)) {
        await SuperAdminService.toggleModule(widget.tenantId, module.id, true);
        if (!mounted) return;
        ref.invalidate(tenantActiveModuleIdsProvider(widget.tenantId));
        ref.invalidate(tenantModuleCancelAtPeriodEndIdsProvider(widget.tenantId));
        ref.invalidate(tenantModuleSubscriptionMapProvider(widget.tenantId));
        ref.invalidate(dashboardMrrProvider);
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;
        setState(() {
          _pending.remove(module.id);
          _togglingModuleId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('super_admin.module_enabled'.tr(namedArgs: {'name': _label(module)})),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
            elevation: 10,
          ),
        );
        return;
      }

      // ─── ZAPÍNÁNÍ (value == true) ───────────────────────────────────────────
      if (value && module.parentModuleKey != null && module.parentModuleKey!.isNotEmpty) {
        // Bezpečně najdi nadřazený modul
        final parent = modules.where((m) => m.key == module.parentModuleKey).firstOrNull;
        if (parent == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('super_admin.module_parent_not_found'.tr()),
              duration: const Duration(seconds: 4),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
              elevation: 10,
            ),
          );
          return;
        }
        // Zkontroluj, zda je parent aktivní (jeho ID v seznamu aktivních modulů)
        if (!activeIds.contains(parent.id)) {
          if (!mounted) return;
          final ok = await _showSubmoduleDependencyDialog(context, module, parent);
          if (!mounted) return;
          if (ok == true) {
            await _activateBothModules(parent, module);
          }
          return;
        }
        // Parent je aktivní – pokračuj standardním zapnutím
      }

      // ─── VYPÍNÁNÍ (value == false) ──────────────────────────────────────────
      if (!value) {
        final activeDependents = modules
            .where((m) =>
                m.parentModuleKey != null &&
                m.parentModuleKey == module.key &&
                activeIds.contains(m.id))
            .toList();
        if (activeDependents.isNotEmpty) {
          if (!mounted) return;
          final ok = await _showDeactivateCascadeDialog(context, module, activeDependents);
          if (!mounted) return;
          if (ok == true) {
            await _deactivateCascade(module, activeDependents);
          }
          return;
        }
        // Žádní závislí – pokračuj standardním vypnutím
      }

      // ─── STANDARDNÍ ZAPNUTÍ/VYPNUTÍ ────────────────────────────────────────
      await SuperAdminService.toggleModule(widget.tenantId, module.id, value);
      if (!mounted) return;

      final auth = ref.read(authNotifierProvider);
      await AuditLogService.log(
        tenantId: auth.tenantIdForData,
        userId: SupabaseService.client.auth.currentUser?.id,
        actionType: value ? 'MODULE_ACTIVATED' : 'MODULE_DEACTIVATED',
        tableName: 'tenant_modules',
        recordId: module.id,
        details: {'tenant_id': widget.tenantId, 'module_key': module.key},
      );

      if (!mounted) return;
      // Vynucené obnovení UI po změně v databázi – prevence rubber-bandingu.
      ref.invalidate(tenantActiveModuleIdsProvider(widget.tenantId));
      ref.invalidate(tenantModuleCancelAtPeriodEndIdsProvider(widget.tenantId));
      ref.invalidate(tenantModuleSubscriptionMapProvider(widget.tenantId));
      ref.invalidate(dashboardMrrProvider);
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() {
        _pending.remove(module.id);
        _togglingModuleId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'super_admin.module_enabled'.tr(namedArgs: {'name': _label(module)})
                : 'super_admin.module_disabled'.tr(namedArgs: {'name': _label(module)}),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          elevation: 10,
        ),
      );
    } catch (e, st) {
      debugPrint('Toggle Error: $e');
      if (kDebugMode) debugPrint('[TenantDetailScreen] stack: $st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.module_toggle_generic_error'.tr()),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          elevation: 10,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pending.remove(module.id);
          _togglingModuleId = null;
        });
      }
    }
  }

  /// Zobrazí dialog závislosti sub-modulu. Vrací true pokud uživatel zvolil „Zapnout oba“.
  /// useRootNavigator: true – aby byl dialog nad overlay a klikatelný.
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
      // Vynucené obnovení UI po změně v databázi – prevence rubber-bandingu.
      ref.invalidate(tenantActiveModuleIdsProvider(widget.tenantId));
      ref.invalidate(tenantModuleCancelAtPeriodEndIdsProvider(widget.tenantId));
      ref.invalidate(tenantModuleSubscriptionMapProvider(widget.tenantId));
      ref.invalidate(dashboardMrrProvider);
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
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
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          elevation: 10,
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
          content: Text('super_admin.module_toggle_generic_error'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          elevation: 10,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Dialog před kaskádovým vypnutím hlavního modulu a jeho aktivních sub-modulů.
  /// useRootNavigator: true – aby byl dialog nad overlay a klikatelný.
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
      // Vynucené obnovení UI po změně v databázi – prevence rubber-bandingu.
      ref.invalidate(tenantActiveModuleIdsProvider(widget.tenantId));
      ref.invalidate(tenantModuleCancelAtPeriodEndIdsProvider(widget.tenantId));
      ref.invalidate(tenantModuleSubscriptionMapProvider(widget.tenantId));
      ref.invalidate(dashboardMrrProvider);
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
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
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          elevation: 10,
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
          content: Text('super_admin.module_toggle_generic_error'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          elevation: 10,
          duration: const Duration(seconds: 4),
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
        final cancelAtPeriodEndIds = ref.watch(tenantModuleCancelAtPeriodEndIdsProvider(widget.tenantId)).valueOrNull ?? {};
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
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                _InfoBillingTab._sectionCard(
                  context,
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
                const SizedBox(height: 24),
                Text(
                  'super_admin.module_management_hint'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[900],
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: modules.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final module = modules[i];
                    final isEnabled = _pending.containsKey(module.id)
                        ? _pending[module.id]!
                        : activeIds.contains(module.id);
                    final isToggling = _togglingModuleId == module.id;
                    final sub = subscriptionMap[module.id];
                    final trialBadge = (sub != null && sub.isTrial && sub.trialEndsAt != null)
                        ? 'super_admin.module_trial_badge'.tr(namedArgs: {'date': _formatTrialDate(sub.trialEndsAt!)})
                        : null;
                    final cancelsAtPeriodEnd = cancelAtPeriodEndIds.contains(module.id);
                    final priceStr = _priceDisplay(module, apartmentCount, userCount, currencies);
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
                      child: Row(
                        children: [
                          Icon(
                            ModuleIconMapper.getIcon(module.key),
                            size: 24,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _label(module),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[900],
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (trialBadge != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    trialBadge,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (cancelsAtPeriodEnd) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.schedule, size: 14, color: Colors.red.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'super_admin.module_cancels_at_period_end'.tr(),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isToggling)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else ...[
                            Text(
                              priceStr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: isEnabled,
                              onChanged: (value) => _onToggle(module, value),
                            ),
                            if (isEnabled) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.settings, size: 20, color: Colors.grey[700]),
                                tooltip: 'settings.module_edit'.tr(),
                                onPressed: () => _openModuleSubscriptionDialog(module, sub),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  },
                ),
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoBillingTab._profileStyleCard(
                context: context,
                color: Colors.blue,
                icon: Icons.apartment,
                title: 'super_admin.stats_apartments_managed'.tr(),
                child: Text(
                  '${stats?.apartmentCount ?? 0}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _InfoBillingTab._profileStyleCard(
                context: context,
                color: Colors.orange,
                icon: Icons.calendar_month,
                title: 'super_admin.stats_reservations_this_month'.tr(),
                child: Text(
                  '${stats?.reservationsThisMonth ?? 0}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'super_admin.section_team'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[900],
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        profilesAsync.when(
          data: (profiles) {
            if (profiles.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'super_admin.team_empty'.tr(),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: profiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final p = profiles[i];
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
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              p.role,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$e', style: TextStyle(color: Colors.red.shade700)),
          ),
        ),
      ],
    );
  }
}
