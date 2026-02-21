import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/models/module_model.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/utils/module_icon_mapper.dart';
import 'package:falconest/features/super_admin/providers/tenant_detail_provider.dart';

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
              const SizedBox(height: 24),
              _buildInvoicesSection(context),
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

  /// Sekce „Moje předplatné“ – aktivní moduly jako Chips + tlačítko Spravovat.
  Widget _buildSubscriptionSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Set<String>> activeKeysAsync,
    AsyncValue<List<ModuleModel>> modulesAsync,
  ) {
    final activeKeys = activeKeysAsync.valueOrNull ?? {};
    final modules = modulesAsync.valueOrNull ?? [];

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activeKeys.isEmpty
                ? [
                    Text(
                      'common.none'.tr(),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ]
                : (activeKeys.map((key) {
                    ModuleModel? found;
                    for (final m in modules) {
                      if (m.key == key) {
                        found = m;
                        break;
                      }
                    }
                    final label = found != null
                        ? ModuleIconMapper.getLabelKey(found.key).tr()
                        : key;
                    return Chip(
                      avatar: Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 18,
                      ),
                      label: Text(label),
                      backgroundColor: Colors.green.shade50,
                    );
                  }).toList()),
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

  /// Sekce „Moje faktury“ – mock položky (2–3 statické).
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
