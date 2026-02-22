import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/providers/admin_reservations_provider.dart';
import 'package:falconest/features/admin/providers/admin_team_provider.dart';
import 'package:falconest/features/admin/providers/admin_tasks_provider.dart';
import 'package:falconest/features/admin/providers/apartments_provider.dart';
import 'package:falconest/features/admin/providers/current_tenant_name_provider.dart';
import 'package:falconest/features/super_admin/super_admin_billing_modal.dart';
import 'package:falconest/features/super_admin/super_admin_settings_modal.dart';
import 'package:falconest/features/super_admin/audit_log_screen.dart';
import 'package:falconest/features/super_admin/providers/all_tenants_provider.dart';
import 'package:falconest/features/super_admin/providers/dashboard_mrr_provider.dart';
import 'package:falconest/features/super_admin/tenant_detail_screen.dart';

/// Stav vyhledávacího řetězce na nástěnce Super Admina (fulltext v názvech agentur).
final superAdminSearchQueryProvider = StateProvider<String>((ref) => '');

/// Typ řazení seznamu agentur na nástěnce.
enum TenantSortType {
  nameAz,
  mrrHigh,
  activityNewest,
  risk,
}

/// Nástěnka super administrátora – přehled všech agentur, vytváření nových,
/// převtělení do vybrané agentury.
///
/// Super_admin vidí seznam všech tenantů (RLS politika) a může:
/// - vytvořit novou agenturu (FAB → dialog),
/// - převtělit se do existující agentury.
class SuperAdminDashboard extends ConsumerWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(tenantsWithStatusProvider);
    final searchQuery = ref.watch(superAdminSearchQueryProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('super_admin.dashboard_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'super_admin.audit_log_menu'.tr(),
            onPressed: () => AuditLogModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'super_admin.billing_menu'.tr(),
            onPressed: () => SuperAdminBillingModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'settings.menu_settings'.tr(),
            onPressed: () => SuperAdminSettingsModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'super_admin.logout'.tr(),
            onPressed: () async {
              await SupabaseService.client.auth.signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: tenantsAsync.when(
        data: (items) {
          final query = searchQuery.trim().toLowerCase();
          final filtered = query.isEmpty
              ? items
              : items.where((i) => _tenantMatchesSearch(i, query)).toList();
          return _DashboardBody(
            items: filtered,
            allItems: items,
            searchQuery: searchQuery,
            ref: ref,
            onAddAgency: () => _showAddAgencyDialog(context, ref),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'super_admin.load_error'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(tenantsWithStatusProvider),
                child: Text('common.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vyhledávání: název, obchodní jméno (company_name), IČO, kontaktní e-mail (billing_info).
  static bool _tenantMatchesSearch(TenantWithStatus item, String query) {
    final t = item.tenant;
    if (t.name.toLowerCase().contains(query)) return true;
    final b = t.billingInfo;
    if (b != null) {
      if ((b.companyName ?? '').toLowerCase().contains(query)) return true;
      if ((b.ico ?? '').toLowerCase().contains(query)) return true;
      if ((b.contactEmail ?? '').toLowerCase().contains(query)) return true;
    }
    return false;
  }

  /// Otevře scrollovatelný formulář pro vytvoření nové agentury a pozvánky.
  /// Po úspěchu OKAMŽITĚ obnoví seznam (ref.refresh) a zobrazí zelený SnackBar.
  void _showAddAgencyDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _AddAgencyDialog(
        onCreated: () {
          // ignore: unused_result - refresh způsobí rebuild přes watch
          ref.refresh(tenantsWithStatusProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('super_admin.agency_invitation_created'.tr()),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }
}

/// Scrollovatelný formulář pro vytvoření nové agentury a pozvánky manažera.
///
/// Ukládá agenturu do tenants a pozvánku do invitations. NEPOUŽÍVÁ signUp(),
/// aby nedošlo k odhlášení Super Admina.
class _AddAgencyDialog extends StatefulWidget {
  const _AddAgencyDialog({required this.onCreated});

  final VoidCallback onCreated;

  @override
  State<_AddAgencyDialog> createState() => _AddAgencyDialogState();
}

class _AddAgencyDialogState extends State<_AddAgencyDialog> {
  final _agencyNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  /// Globální chybová hláška – zobrazuje se nad formulářem a ZALAMUJE se
  /// na více řádků (bez overflow), aby dlouhé chyby byly čitelné.
  String? _globalError;

  static final _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  @override
  void dispose() {
    _agencyNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateAgencyName(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'super_admin.validation_name_required'.tr();
    }
    return null;
  }

  String? _validateFirstName(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'super_admin.validation_first_name_required'.tr();
    }
    return null;
  }

  String? _validateLastName(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'super_admin.validation_last_name_required'.tr();
    }
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'super_admin.validation_email_required'.tr();
    }
    if (!_emailRegex.hasMatch(v.trim())) {
      return 'super_admin.validation_email_format'.tr();
    }
    return null;
  }

  Future<void> _submit() async {
    _globalError = null;

    if (!_formKey.currentState!.validate()) return;

    final name = _agencyNameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();

    setState(() => _isLoading = true);

    try {
      // a) Vytvoř agenturu a získej tenant_id
      final tenantRes = await SupabaseService.client
          .from('tenants')
          .insert({'name': name})
          .select('id')
          .single();

      final tenantId = tenantRes['id'] as String?;
      if (tenantId == null || tenantId.isEmpty) {
        throw Exception('super_admin.create_agency_id_error'.tr());
      }

      // b) Core moduly – každá nová agentura má od začátku přístup (tenant_modules používá module_id UUID).
      try {
        const coreKeys = ['dashboard', 'apartments', 'reservations', 'tasks'];
        final modulesRes = await SupabaseService.client
            .from('modules')
            .select('id')
            .inFilter('key', coreKeys);
        final modulesList = modulesRes as List;
        for (final row in modulesList) {
          final id = (row is Map ? row['id'] : null)?.toString();
          if (id == null || id.isEmpty) continue;
          await SupabaseService.client.from('tenant_modules').insert({
            'tenant_id': tenantId,
            'module_id': id,
          });
        }
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Warning: Failed to seed core modules: $e');
        }
      }

      // c) Startovací balíček: demo apartmán + rezervace + úkol. Při chybě pouze log, agentura se vytvoří.
      try {
        final demoName = 'super_admin.demo_apartment_name'.tr();
        final demoAddress = 'super_admin.demo_apartment_address'.tr();
        final apartmentRes = await SupabaseService.client
            .from('apartments')
            .insert({
              'name': demoName,
              'address': demoAddress,
              'tenant_id': tenantId,
            })
            .select('id')
            .single();
        final apartmentId = apartmentRes['id'];
        if (apartmentId != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final endDate = today.add(const Duration(days: 3));
          final tomorrow = today.add(const Duration(days: 1));
          final guestName = 'super_admin.demo_guest_name'.tr();
          await SupabaseService.client.from('reservations').insert({
            'apartment_id': apartmentId,
            'guest_name': guestName,
            'start_date': today.toIso8601String(),
            'end_date': endDate.toIso8601String(),
            'status': 'confirmed',
          });
          final tomorrowIso = tomorrow.toIso8601String();
          await SupabaseService.client.from('tasks').insert({
            'tenant_id': tenantId,
            'apartment_id': apartmentId,
            'title': 'super_admin.demo_task_title'.tr(),
            'description': 'super_admin.demo_task_description'.tr(),
            'status': 'Nový',
            'task_type': 'cleaning',
            'due_date': tomorrowIso,
            'scheduled_start': tomorrowIso,
          });
        }
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Warning: Failed to seed demo data: $e');
        }
      }

      // d) Ghost Profile Strategy: nejprve profil (status=pending), pak pozvánka
      final profileRes = await SupabaseService.client
          .from('profiles')
          .insert({
            'tenant_id': tenantId,
            'email': email,
            'first_name': firstName,
            'last_name': lastName,
            'name': '$firstName $lastName'.trim(),
            'status': 'pending',
          })
          .select('id')
          .single();
      final profileId = profileRes['id'] as String?;
      if (profileId == null || profileId.isEmpty) {
        throw Exception('super_admin.create_profile_error'.tr());
      }
      await SupabaseService.client.from('invitations').insert({
        'tenant_id': tenantId,
        'profile_id': profileId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': 'admin',
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _globalError = '${'common.error'.tr()}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'super_admin.dialog_add_title'.tr(),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Globální chyba – ZALAMOVÁNÍ na více řádků (žádný overflow)
                      if (_globalError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _globalError!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 14,
                            ),
                            softWrap: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _agencyNameController,
                        decoration: InputDecoration(
                          labelText: 'super_admin.field_agency_name'.tr(),
                          border: const OutlineInputBorder(),
                          errorMaxLines: 3,
                        ),
                        textCapitalization: TextCapitalization.words,
                        enabled: !_isLoading,
                        autofocus: true,
                        validator: _validateAgencyName,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'super_admin.field_manager_first_name'.tr(),
                          border: const OutlineInputBorder(),
                          errorMaxLines: 3,
                        ),
                        textCapitalization: TextCapitalization.words,
                        enabled: !_isLoading,
                        validator: _validateFirstName,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'super_admin.field_manager_last_name'.tr(),
                          border: const OutlineInputBorder(),
                          errorMaxLines: 3,
                        ),
                        textCapitalization: TextCapitalization.words,
                        enabled: !_isLoading,
                        validator: _validateLastName,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'super_admin.field_manager_email'.tr(),
                          border: const OutlineInputBorder(),
                          errorMaxLines: 3,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enabled: !_isLoading,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Text('common.cancel'.tr()),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('super_admin.btn_create_agency'.tr()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Globální Megafon: dva stavy – bez aktivní zprávy (TextField + Rozeslat) nebo
/// panel „Aktuálně vysíláte“ + tlačítko Zastavit vysílání.
class _MegaphoneCard extends StatefulWidget {
  const _MegaphoneCard({
    required this.controller,
    required this.ref,
    this.activeAnnouncement,
  });

  final TextEditingController controller;
  final WidgetRef ref;
  /// Neprázdná zpráva = právě se vysílá všem (STAV B).
  final String? activeAnnouncement;

  @override
  State<_MegaphoneCard> createState() => _MegaphoneCardState();
}

class _MegaphoneCardState extends State<_MegaphoneCard> {
  bool _sending = false;

  Future<void> _send() async {
    final msg = widget.controller.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    try {
      await broadcastAnnouncementToActiveTenants(msg);
      if (!mounted) return;
      // ignore: unused_result
      widget.ref.refresh(tenantsWithStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.megaphone_sent'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _stopBroadcast() async {
    setState(() => _sending = true);
    try {
      await clearAnnouncementForAllTenants();
      if (!mounted) return;
      // ignore: unused_result
      widget.ref.refresh(tenantsWithStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.megaphone_cleared'.tr()),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _clear() async {
    setState(() => _sending = true);
    try {
      await broadcastAnnouncementToActiveTenants(null);
      widget.controller.clear();
      if (!mounted) return;
      // ignore: unused_result
      widget.ref.refresh(tenantsWithStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('super_admin.megaphone_cleared'.tr()),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeAnnouncement != null && widget.activeAnnouncement!.trim().isNotEmpty;

    if (active) {
      // STAV B: Aktivní zpráva – panel + Zastavit vysílání
      return Card(
        elevation: 2,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.campaign, color: Colors.orange.shade800, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'super_admin.megaphone_broadcasting'.tr(
                    namedArgs: {'message': widget.activeAnnouncement!},
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _sending
                    ? null
                    : _stopBroadcast,
                icon: const Icon(Icons.cancel, size: 20),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                label: Text('super_admin.megaphone_stop_broadcast'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    // STAV A: Žádná aktivní zpráva – TextField + Rozeslat všem + Vymazat
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.campaign, color: Colors.blue.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: widget.controller,
                enabled: !_sending,
                decoration: InputDecoration(
                  hintText: 'super_admin.megaphone_placeholder'.tr(),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send, size: 20),
              label: Text('super_admin.megaphone_send_all'.tr()),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sending ? null : _clear,
              tooltip: 'super_admin.megaphone_clear'.tr(),
              icon: Icon(Icons.close, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tělo nástěnky: KPI karty, vyhledávání, seznam agentur (nebo prázdný stav).
class _DashboardBody extends ConsumerStatefulWidget {
  const _DashboardBody({
    required this.items,
    required this.allItems,
    required this.searchQuery,
    required this.ref,
    required this.onAddAgency,
  });

  final List<TenantWithStatus> items;
  final List<TenantWithStatus> allItems;
  final String searchQuery;
  final WidgetRef ref;
  final VoidCallback onAddAgency;

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  late final TextEditingController _searchController;
  late final TextEditingController _megaphoneController;
  TenantSortType _currentSortType = TenantSortType.nameAz;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _megaphoneController = TextEditingController();
  }

  /// Seřadí seznam agentur podle zvoleného kritéria. Null hodnoty: u MRR/aktivita dole, u Riziko null nahoře.
  List<TenantWithStatus> _applySort(
    List<TenantWithStatus> items,
    Map<String, double> perTenantEur,
    TenantSortType sortType,
  ) {
    final list = List<TenantWithStatus>.from(items);
    switch (sortType) {
      case TenantSortType.nameAz:
        list.sort((a, b) => a.tenant.name.toLowerCase().compareTo(b.tenant.name.toLowerCase()));
        break;
      case TenantSortType.mrrHigh:
        list.sort((a, b) {
          final mrrA = perTenantEur[a.tenant.id] ?? 0.0;
          final mrrB = perTenantEur[b.tenant.id] ?? 0.0;
          if (mrrA != mrrB) return mrrB.compareTo(mrrA);
          return a.tenant.name.compareTo(b.tenant.name);
        });
        break;
      case TenantSortType.activityNewest:
        list.sort((a, b) {
          final atA = a.latestActivityAt;
          final atB = b.latestActivityAt;
          if (atA == null && atB == null) return a.tenant.name.compareTo(b.tenant.name);
          if (atA == null) return 1;
          if (atB == null) return -1;
          return atB.compareTo(atA);
        });
        break;
      case TenantSortType.risk:
        list.sort((a, b) {
          final atA = a.latestActivityAt;
          final atB = b.latestActivityAt;
          if (atA == null && atB == null) return a.tenant.name.compareTo(b.tenant.name);
          if (atA == null) return -1;
          if (atB == null) return 1;
          return atA.compareTo(atB);
        });
        break;
    }
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _megaphoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final allItems = widget.allItems;
    final ref = widget.ref;
    final totalAgencies = allItems.length;
    final activeCount = allItems.where((i) => i.isActive).length;
    final totalApartments = allItems.fold<int>(
      0,
      (sum, i) => sum + (i.apartmentCount ?? 0),
    );

    final mrrAsync = ref.watch(dashboardMrrProvider);
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
    final displayCurrency = ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final totalMrrFormatted = mrrAsync.valueOrNull != null && currencies.isNotEmpty
        ? CurrencyService.formatPrice(
            mrrAsync.valueOrNull!.totalEur,
            displayCurrency,
            currencies,
          )
        : (mrrAsync.valueOrNull != null ? '€ ${mrrAsync.valueOrNull!.totalEur.toStringAsFixed(2)}' : '—');
    final perTenantEur = mrrAsync.valueOrNull?.perTenantEur ?? {};

    // Aktivní zpráva Megafonu: první aktivní tenant s neprázdným system_announcement
    String? activeAnnouncement;
    for (final item in allItems) {
      if (item.tenant.isActive) {
        final s = item.tenant.systemAnnouncement;
        if (s != null && s.trim().isNotEmpty) {
          activeAnnouncement = s.trim();
          break;
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MegaphoneCard(
            controller: _megaphoneController,
            ref: ref,
            activeAnnouncement: activeAnnouncement,
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _KpiCard(
                    title: 'super_admin.kpi_total_agencies'.tr(),
                    value: '$totalAgencies',
                    icon: Icons.business_center,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    title: 'super_admin.kpi_active_clients'.tr(),
                    value: '$activeCount',
                    icon: Icons.verified_user,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    title: 'super_admin.kpi_total_apartments'.tr(),
                    value: '$totalApartments',
                    icon: Icons.apartment,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    title: 'super_admin.kpi_total_mrr'.tr(),
                    value: totalMrrFormatted,
                    icon: Icons.euro,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      ref.read(superAdminSearchQueryProvider.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'super_admin.search_placeholder'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                child: PopupMenuButton<TenantSortType>(
                  onSelected: (v) => setState(() => _currentSortType = v),
                  offset: const Offset(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: TenantSortType.nameAz,
                      child: Text('super_admin.sort_name_az'.tr()),
                    ),
                    PopupMenuItem(
                      value: TenantSortType.mrrHigh,
                      child: Text('super_admin.sort_mrr_high'.tr()),
                    ),
                    PopupMenuItem(
                      value: TenantSortType.activityNewest,
                      child: Text('super_admin.sort_activity_newest'.tr()),
                    ),
                    PopupMenuItem(
                      value: TenantSortType.risk,
                      child: Text('super_admin.sort_risk'.tr()),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort_rounded, size: 20, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'super_admin.sort_button'.tr(),
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: widget.onAddAgency,
                icon: const Icon(Icons.add),
                label: Text('super_admin.add_agency'.tr()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (items.isEmpty)
            _EmptyState()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final sortedItems = _applySort(items, perTenantEur, _currentSortType);
                final width = constraints.maxWidth;
                final crossAxisCount = width > 900 ? 4 : width > 600 ? 3 : width > 400 ? 2 : 1;
                const spacing = 12.0;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: 1.95,
                  ),
                  itemCount: sortedItems.length,
                  itemBuilder: (context, index) {
                    final item = sortedItems[index];
                    final tenantEur = perTenantEur[item.tenant.id] ?? 0;
                    final mrrFormatted = currencies.isNotEmpty
                        ? CurrencyService.formatPrice(tenantEur, displayCurrency, currencies)
                        : '€ ${tenantEur.toStringAsFixed(2)}';
                    return _TenantCard(
                      item: item,
                      ref: ref,
                      mrrFormatted: mrrFormatted,
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}


/// Jedna KPI karta – bílá, 24px radius, stín; velká tučná čísla (Apple styl).
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
          ),
        ],
      ),
    );
  }
}

/// Prázdný stav – ikona, nadpis a podnadpis s návodem.
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.domain_disabled,
              size: 96,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'super_admin.empty_title'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'super_admin.empty_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kompaktní karta agentury („Compact Hybrid“): 4 řádky, vysoká hustota informací.
/// Kontejner: bílá, radius 16, jemný stín, auto výška. Klik na tělo → TenantDetailModal (kompletní detail).
class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.item,
    required this.ref,
    required this.mrrFormatted,
  });

  final TenantWithStatus item;
  final WidgetRef ref;
  final String mrrFormatted;

  /// Chytrý semafor: Pozastaveno → Nezaplaceno → V Trialu → Aktivní.
  static ({Color bg, Color fg, String labelKey}) _statusBadgeStyle(TenantRow tenant) {
    if (!tenant.isActive) {
      return (bg: Colors.grey.shade200, fg: Colors.grey.shade800, labelKey: 'super_admin.status_suspended');
    }
    final now = DateTime.now().toUtc();
    if (tenant.paidUntil != null) {
      final endOfPaidDay = DateTime.utc(
        tenant.paidUntil!.year, tenant.paidUntil!.month, tenant.paidUntil!.day, 23, 59, 59,
      );
      if (now.isAfter(endOfPaidDay)) {
        return (bg: Colors.red.shade100, fg: Colors.red.shade800, labelKey: 'super_admin.billing_unpaid');
      }
    }
    if (tenant.trialEndsAt != null && tenant.trialEndsAt!.isAfter(now)) {
      return (bg: Colors.green.shade100, fg: Colors.green.shade800, labelKey: 'super_admin.billing_in_trial');
    }
    return (bg: Colors.green.shade100, fg: Colors.green.shade800, labelKey: 'super_admin.status_active');
  }

  /// Subtitle pod názvem agentury: company name (+ IČO), nebo jen IČO, nebo datum registrace.
  static String? _cardSubtitle(BuildContext context, TenantRow tenant) {
    final b = tenant.billingInfo;
    final companyName = b?.companyName?.trim();
    final ico = b?.ico?.trim();
    if (companyName != null && companyName.isNotEmpty) {
      if (ico != null && ico.isNotEmpty) {
        return '$companyName${'super_admin.card_subtitle_ico_suffix'.tr(namedArgs: {'ico': ico})}';
      }
      return companyName;
    }
    if (ico != null && ico.isNotEmpty) {
      return 'super_admin.card_subtitle_ico_only'.tr(namedArgs: {'ico': ico});
    }
    if (tenant.createdAt != null) {
      final d = tenant.createdAt!;
      final dateStr = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
      return 'super_admin.registered_date'.tr(namedArgs: {'date': dateStr});
    }
    return null;
  }

  /// Formátuje paid_until pro zobrazení (dd.MM.yyyy) nebo "Nenastaveno".
  static String _formatPaidUntil(DateTime? d) {
    if (d == null) return 'super_admin.billing_not_set'.tr();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  /// Health (Traffic Light): < 24h zelená (hodiny), 24h–7d amber (dny), > 7d nebo null červená.
  static ({Color dotColor, Color textColor, String labelKey, Map<String, String>? args}) _healthStyle(DateTime? latestActivityAt) {
    if (latestActivityAt == null) {
      return (dotColor: Colors.red, textColor: Colors.red.shade800, labelKey: 'super_admin.health_inactive', args: null);
    }
    final now = DateTime.now().toUtc();
    final at = latestActivityAt.isUtc ? latestActivityAt : latestActivityAt.toUtc();
    final diff = now.difference(at);
    final days = diff.inDays;
    final hours = diff.inHours;
    if (hours < 24) {
      return (dotColor: Colors.green, textColor: Colors.green.shade800, labelKey: hours <= 1 ? 'super_admin.health_online_today' : 'super_admin.health_online_hours_ago', args: hours <= 1 ? null : {'hours': '$hours'});
    }
    if (days <= 7) {
      return (dotColor: Colors.amber, textColor: Colors.amber.shade800, labelKey: 'super_admin.health_online_days_ago', args: {'days': '$days'});
    }
    return (dotColor: Colors.red, textColor: Colors.red.shade800, labelKey: 'super_admin.health_inactive_days', args: {'days': '$days'});
  }

  @override
  Widget build(BuildContext context) {
    final tenant = item.tenant;
    final activeUsersCount = item.activeUsersCount ?? 0;
    final pendingInvitationsCount = item.pendingInvitationsCount;
    final apartmentCount = item.apartmentCount ?? 0;
    final status = _statusBadgeStyle(tenant);
    final health = _healthStyle(item.latestActivityAt);
    final activeMod = item.moduleActiveCount;
    final totalMod = item.moduleTotalCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => TenantDetailModal.show(context, tenant.id, tenantName: tenant.name),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Řádek 1: Název (18, bold) + Status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tenant.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.labelKey.tr(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: status.fg),
                      ),
                    ),
                  ],
                ),
                if (_cardSubtitle(context, tenant) != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _cardSubtitle(context, tenant)!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                // Jeden řádek: vlevo metriky (lidé, byty, moduly), vpravo MRR + sleva + Health (využití šířky karty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 16, color: Colors.grey.shade600),
                        Text(
                          ' $activeUsersCount${pendingInvitationsCount > 0 ? ' (+$pendingInvitationsCount)' : ''}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.apartment_outlined, size: 16, color: Colors.grey.shade600),
                        Text(
                          ' $apartmentCount',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.diamond, size: 12, color: Colors.blue.shade700),
                              Text(
                                ' $activeMod/$totalMod',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              mrrFormatted,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.green.shade800,
                              ),
                            ),
                            if (tenant.discountPercentage > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Text(
                                  'super_admin.discount_badge_percent'.tr(namedArgs: {'percent': '${tenant.discountPercentage}'}),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 4,
                                  backgroundColor: health.dotColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  health.args != null
                                      ? health.labelKey.tr(namedArgs: health.args!)
                                      : health.labelKey.tr(),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '${'super_admin.billing_paid_until'.tr()}: ${_formatPaidUntil(tenant.paidUntil)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 12),
                // Řádek 4: Přepínač + Delete + Převtělit se
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch.adaptive(
                          value: tenant.isActive,
                          onChanged: (_) => _onToggleActive(context, ref),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade600),
                          onPressed: () => _onDeleteTenant(context, ref),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: 'super_admin.menu_delete'.tr(),
                        ),
                      ],
                    ),
                    OutlinedButton(
                      onPressed: () => _onImpersonate(context, ref, tenant),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: Text('super_admin.impersonate'.tr(), style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onDeleteTenant(BuildContext context, WidgetRef ref) async {
    final tenant = item.tenant;
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
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('super_admin.btn_delete'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await SupabaseService.client.from('invitations').delete().eq('tenant_id', tenant.id);
    } catch (_) {}
    try {
      // Soft Delete: místo tvrdého DELETE nastavíme deleted_at – zachová Audit Log a historii dat.
      final deletedAt = DateTime.now().toUtc().toIso8601String();
      await SupabaseService.client
          .from('tenants')
          .update({'deleted_at': deletedAt})
          .eq('id', tenant.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'common.error'.tr()}: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    // ignore: unused_result
    ref.refresh(tenantsWithStatusProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('super_admin.agency_deleted'.tr()),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onToggleActive(BuildContext context, WidgetRef ref) async {
    final tenant = item.tenant;
    try {
      await SupabaseService.client
          .from('tenants')
          .update({'is_active': !tenant.isActive})
          .eq('id', tenant.id);
      if (!context.mounted) return;
      // ignore: unused_result
      ref.refresh(tenantsWithStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tenant.isActive
                ? 'super_admin.agency_suspended'.tr()
                : 'super_admin.agency_activated'.tr(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'common.error'.tr()}: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onImpersonate(
    BuildContext context,
    WidgetRef ref,
    TenantRow tenant,
  ) async {
    final tenantId = tenant.id;
    // Krok A+B: změna globálního stavu (tenant_id v profilu) a invalidace dat
    try {
      // ignore: avoid_print
      if (kDebugMode) print('super_admin.debug_impersonate'.tr(namedArgs: {'id': tenantId}));
      await ref.read(authNotifierProvider).impersonateTenant(tenantId);
      if (!context.mounted) return;

      // Krok B: invalidace providerů, aby se po přepnutí načetla data vybrané agentury
      ref.invalidate(adminTasksProvider);
      ref.invalidate(adminReservationsProvider);
      ref.invalidate(apartmentsProvider);
      ref.invalidate(adminTeamProvider);
      ref.invalidate(staffAbsencesProvider);
      ref.invalidate(currentTenantNameProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'super_admin.impersonate_success'.tr(namedArgs: {'name': tenant.name}),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Krok C: přesměrování na Nástěnku administrace
      context.go('/admin');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'super_admin.impersonate_error'.tr(namedArgs: {'error': '$e'}),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
