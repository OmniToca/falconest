import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/currency_service.dart';
import 'package:falconest/features/admin/models/module_model.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/utils/module_icon_mapper.dart';
import 'package:falconest/features/settings/module_editor_screen.dart';
import 'package:falconest/features/settings/pricing_type_label.dart';
import 'package:falconest/features/settings/providers/tenant_services_provider.dart';
import 'package:falconest/features/settings/service_editor_dialog.dart';
import 'package:falconest/features/settings/supported_languages.dart';
import 'package:falconest/features/settings/client_billing_tab.dart';
import 'package:falconest/features/settings/user_profile_tab.dart';
import 'package:falconest/features/settings/zones_list_tab.dart';
import 'package:falconest/features/settings/models/tenant_service_model.dart';
import 'package:falconest/features/super_admin/services/super_admin_service.dart';

/// Modální dialog Nastavení – stejný vizuál jako TenantCommandModal (centrované okno, karty).
/// Z menu volat SettingsModal.show(context) místo context.push('/settings').
class SettingsModal {
  SettingsModal._();

  /// Otevře Nastavení jako modální dialog (blur, centrované okno). Z menu volat místo context.push('/settings').
  static Future<void> show(BuildContext hostContext) {
    return showGeneralDialog<void>(
      context: hostContext,
      barrierDismissible: true,
      barrierLabel: 'Settings',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      transitionBuilder: (_, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              child: _SettingsModalContent(
                pushContext: hostContext,
                isDialogMode: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Sdílený obsah modalu – buď v dialogu (isDialogMode + pushContext), nebo na route (SettingsScreen).
class _SettingsModalContent extends ConsumerWidget {
  const _SettingsModalContent({
    this.pushContext,
    this.isDialogMode = false,
  });

  /// Kontext volajícího – v režimu dialogu se použije pro pop + push (zavřít modal, otevřít editor).
  final BuildContext? pushContext;
  final bool isDialogMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Záložka Fakturace jen pro admin a manager – mají kontext tenanta pro správu fakturačních údajů.
    final showBillingTab = ref.watch(authNotifierProvider).state.isAdminOrManager;
    final isSuperAdmin = ref.watch(authNotifierProvider).state.role == 'super_admin';

    final tabs = <Widget>[];
    final tabViews = <Widget>[];

    if (isSuperAdmin) {
      // Super Admin: Profil + Moduly (pouze katalog modulů, bez Služeb a Oblasti)
      tabs.add(Tab(text: 'settings.tab_profile'.tr()));
      tabViews.add(const UserProfileTab());
      tabs.add(Tab(text: 'settings.catalog_modules'.tr()));
      tabViews.add(_ServicesTabContent(
        onAddService: () => _onAddService(context),
        onEditService: (s) => _onEditService(context, s),
        onAddModule: () => _onAddModule(context),
        onEditModule: (m) => _onEditModule(context, m),
        pushContext: pushContext,
        isDialogMode: isDialogMode,
        showOnlyModules: true,
      ));
    } else {
      // Běžný Admin/Worker: Profil, Služby, Oblasti, volitelně Fakturace
      tabs.add(Tab(text: 'settings.tab_profile'.tr()));
      tabViews.add(const UserProfileTab());
      tabs.add(Tab(text: 'settings.tab_services'.tr()));
      tabViews.add(_ServicesTabContent(
        onAddService: () => _onAddService(context),
        onEditService: (s) => _onEditService(context, s),
        onAddModule: () => _onAddModule(context),
        onEditModule: (m) => _onEditModule(context, m),
        pushContext: pushContext,
        isDialogMode: isDialogMode,
        showOnlyModules: false,
      ));
      tabs.add(Tab(text: 'settings.tab_zones'.tr()));
      tabViews.add(const _ZonesTabContent());
      if (showBillingTab) {
        tabs.add(Tab(text: 'settings.tab_billing'.tr()));
        tabViews.add(const ClientBillingTab());
      }
    }

    final tabCount = tabs.length;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                Flexible(
                  child: DefaultTabController(
                    length: tabCount,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildProfileSection(context, ref),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: TabBar(
                            labelColor: Theme.of(context).colorScheme.primary,
                            unselectedLabelColor: Colors.grey.shade600,
                            indicatorColor: Theme.of(context).colorScheme.primary,
                            tabs: tabs,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TabBarView(
                            children: tabViews,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onClose(BuildContext context) {
    if (isDialogMode && pushContext != null) {
      Navigator.of(pushContext!).pop();
    } else {
      context.pop();
    }
  }

  void _onAddModule(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const ModuleEditorScreen(asDialog: true),
    );
  }

  void _onEditModule(BuildContext context, ModuleModel module) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ModuleEditorScreen(
        existingModule: module,
        asDialog: true,
      ),
    );
  }

  /// Otevře dialog pro přidání nové služby do katalogu agentury.
  void _onAddService(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const ServiceEditorDialog(existing: null),
    );
  }

  /// Otevře dialog pro úpravu existující služby.
  void _onEditService(BuildContext context, TenantServiceModel service) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ServiceEditorDialog(existing: service),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'settings.title'.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'common.cancel'.tr(),
            onPressed: () => _onClose(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final languageCode = auth.state.languageCode ?? 'cs';
    final preferredCurrency = auth.state.preferredCurrency ?? 'CZK';
    final currenciesAsync = ref.watch(currenciesProvider);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SettingsProfileCard(
              icon: Icons.language_rounded,
              color: Colors.blue,
              title: 'settings.language_label'.tr(),
              child: DropdownButtonFormField<String>(
                initialValue: supportedLanguages.any((e) => e['code'] == languageCode) ? languageCode : 'cs',
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: supportedLanguages.map((e) {
                  final code = e['code']!;
                  final label = e['label']!;
                  final flag = _flagForCode(code);
                  return DropdownMenuItem<String>(value: code, child: Text('$flag $label'));
                }).toList(),
                onChanged: (String? newCode) async {
                  if (newCode == null || newCode == languageCode) return;
                  await ref.read(authNotifierProvider.notifier).updateLanguageCode(newCode);
                  if (context.mounted) await context.setLocale(Locale(newCode));
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SettingsProfileCard(
              icon: Icons.attach_money_rounded,
              color: Colors.green,
              title: 'settings.currency_label'.tr(),
              child: currenciesAsync.when(
                data: (currencies) {
                  final codes = currencies.isEmpty ? <String>['CZK', 'EUR', 'USD'] : currencies.map((c) => c.code).toList();
                  String labelFor(String code) {
                    for (final c in currencies) {
                      if (c.code == code) return '${c.code} ${c.symbol}';
                    }
                    return code;
                  }
                  final value = codes.contains(preferredCurrency) ? preferredCurrency : (codes.isNotEmpty ? codes.first : 'CZK');
                  return DropdownButtonFormField<String>(
                    initialValue: value,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: codes.map((code) => DropdownMenuItem<String>(value: code, child: Text(labelFor(code)))).toList(),
                    onChanged: (String? newCode) async {
                      if (newCode == null || newCode == preferredCurrency) return;
                      await ref.read(authNotifierProvider.notifier).updatePreferredCurrency(newCode);
                    },
                  );
                },
                loading: () => DropdownButtonFormField<String>(
                  initialValue: preferredCurrency,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ['CZK', 'EUR', 'USD'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: null,
                ),
                error: (_, _) => DropdownButtonFormField<String>(
                  initialValue: preferredCurrency,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ['CZK', 'EUR', 'USD'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (String? newCode) async {
                    if (newCode == null || newCode == preferredCurrency) return;
                    await ref.read(authNotifierProvider.notifier).updatePreferredCurrency(newCode);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _flagForCode(String code) {
    switch (code) {
      case 'cs':
        return '🇨🇿';
      case 'en':
        return '🇬🇧';
      case 'es':
        return '🇪🇸';
      default:
        return '🌐';
    }
  }
}

/// Obsah záložky Služby – seznam služeb, tlačítko přidat, katalog modulů (pro super admin).
/// Používá AutomaticKeepAliveClientMixin, aby se stav při přepnutí záložek nenačítal znovu.
class _ServicesTabContent extends ConsumerStatefulWidget {
  const _ServicesTabContent({
    required this.onAddService,
    required this.onEditService,
    required this.onAddModule,
    required this.onEditModule,
    this.pushContext,
    this.isDialogMode = false,
    this.showOnlyModules = false,
  });

  final VoidCallback onAddService;
  final void Function(TenantServiceModel) onEditService;
  final VoidCallback onAddModule;
  final void Function(ModuleModel) onEditModule;
  final BuildContext? pushContext;
  final bool isDialogMode;
  /// True = Super Admin záložka "Moduly" – zobrazí pouze katalog modulů, bez Katalog služeb agentury.
  final bool showOnlyModules;

  @override
  ConsumerState<_ServicesTabContent> createState() => _ServicesTabContentState();
}

class _ServicesTabContentState extends ConsumerState<_ServicesTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.showOnlyModules) ...[
            _buildServicesCatalogSection(context, ref),
            const SizedBox(height: 24),
          ],
          _buildModuleCatalogSection(context, ref),
        ],
      ),
    );
  }

  Widget _buildServicesCatalogSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'settings.catalog_services'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[900],
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            FilledButton.icon(
              onPressed: widget.onAddService,
              icon: const Icon(Icons.add, size: 18),
              label: Text('settings.add_service'.tr()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ServiceListInModal(onEditService: widget.onEditService),
      ],
    );
  }

  Widget _buildModuleCatalogSection(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(authNotifierProvider).state.role == 'super_admin';
    if (!isSuperAdmin) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'settings.catalog_modules'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[900],
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            FilledButton.icon(
              onPressed: widget.onAddModule,
              icon: const Icon(Icons.add, size: 18),
              label: Text('settings.add_module'.tr()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ModuleListInModal(onEditModule: widget.onEditModule),
        const SizedBox(height: 24),
        const _ExchangeRatesCard(),
      ],
    );
  }
}

/// Obsah záložky Oblasti – seznam oblastí a tlačítko přidat. Zachová stav při přepnutí.
class _ZonesTabContent extends ConsumerStatefulWidget {
  const _ZonesTabContent();

  @override
  ConsumerState<_ZonesTabContent> createState() => _ZonesTabContentState();
}

class _ZonesTabContentState extends ConsumerState<_ZonesTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: ZonesListTab(showAddButton: true),
    );
  }
}

/// Hero-style karta v sekci Můj profil (Jazyk / Měna) – pastelové pozadí, ikona, název, dropdown uvnitř.
class _SettingsProfileCard extends StatelessWidget {
  const _SettingsProfileCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

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
}

/// Obrazovka Nastavení na route /settings – zobrazí stejný obsah jako modal (pro přímý odkaz).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: _SettingsModalContent(pushContext: null, isDialogMode: false),
    );
  }
}

/// Seznam služeb katalogu agentury v modalu – stejný vizuál jako seznam modulů (karty, řazení podle order_index).
class _ServiceListInModal extends ConsumerWidget {
  const _ServiceListInModal({required this.onEditService});

  final void Function(TenantServiceModel) onEditService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(tenantServicesProvider);
    return servicesAsync.when(
      data: (services) {
        if (services.isEmpty) {
          return Text(
            'settings.service_list_empty'.tr(),
            style: TextStyle(color: Colors.grey.shade600),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _ServiceCardRow(
            service: services[i],
            onEdit: onEditService,
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (err, _) => Text(
        'common.error_with_message'.tr(namedArgs: {'message': err.toString()}),
        style: TextStyle(color: Colors.red.shade700),
      ),
    );
  }
}

/// Jedna karta služby – bílá, 16 radius, stín; ikona podle typu | šedý kroužek order_index | název | štítek typu | výchozí cena | Upravit | Smazat.
class _ServiceCardRow extends ConsumerWidget {
  const _ServiceCardRow({required this.service, required this.onEdit});

  final TenantServiceModel service;
  final void Function(TenantServiceModel) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ceny v DB jsou v EUR; zobrazujeme je v uživatelově preferované měně (kurz z currencies).
    final preferredCurrency = ref.watch(authNotifierProvider).state.preferredCurrency ?? 'EUR';
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
    final effectiveCurrencies = currencies.isEmpty
        ? [const CurrencyRow(code: 'EUR', symbol: '€', rate: 1.0)]
        : currencies;
    final priceStr = service.defaultPrice != null
        ? CurrencyService.formatPrice(
            service.defaultPrice!.toDouble(),
            preferredCurrency,
            effectiveCurrencies,
          )
        : 'settings.service_price_na'.tr();
    final typeKey = 'settings.service_type_${service.serviceType}';

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
          Icon(_serviceTypeIcon(service.serviceType), size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              service.orderIndex.toString(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              service.name,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[900], fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              typeKey.tr(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
            ),
          ),
          const SizedBox(width: 8),
          Text(priceStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[800])),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey[700]),
            tooltip: 'settings.service_edit'.tr(),
            onPressed: () => onEdit(service),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
            tooltip: 'settings.service_delete'.tr(),
            onPressed: () => _confirmDeleteService(context, ref, service),
          ),
        ],
      ),
    );
  }
}

/// Ikona podle service_type (cleaning, transfer, check_in, check_out, maintenance, extra).
IconData _serviceTypeIcon(String type) {
  switch (type) {
    case 'cleaning':
      return Icons.cleaning_services_rounded;
    case 'transfer':
      return Icons.directions_car_rounded;
    case 'check_in':
    case 'check_out':
      return Icons.key_rounded;
    case 'maintenance':
      return Icons.build_rounded;
    case 'extra':
    default:
      return Icons.add_circle_outline_rounded;
  }
}

/// Potvrzení a soft-delete služby; po úspěchu invaliduje tenantServicesProvider.
Future<void> _confirmDeleteService(BuildContext context, WidgetRef ref, TenantServiceModel service) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('settings.service_delete'.tr()),
      content: Text('settings.service_delete_confirm'.tr()),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('common.cancel'.tr())),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: Text('settings.service_delete'.tr()),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await TenantServicesRepository.softDelete(service.id);
    ref.invalidate(tenantServicesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.service_deleted'.tr()), behavior: SnackBarBehavior.floating),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.service_delete_error'.tr(namedArgs: {'message': e.toString()})),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Seznam modulů v modalu – ListView karet (každá bílá, 16 radius, stín). Předává onEditModule pro Edit.
class _ModuleListInModal extends ConsumerWidget {
  const _ModuleListInModal({required this.onEditModule});

  final void Function(ModuleModel) onEditModule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(allModulesProvider);
    return modulesAsync.when(
      data: (modules) {
        if (modules.isEmpty) {
          return Text(
            'super_admin.module_list_empty'.tr(),
            style: TextStyle(color: Colors.grey.shade600),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _ModuleCardRow(
            module: modules[i],
            onEdit: onEditModule,
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (err, _) => Text(
        'common.error_with_message'.tr(namedArgs: {'message': err.toString()}),
        style: TextStyle(color: Colors.red.shade700),
      ),
    );
  }
}

/// Jedna karta modulu v modalu – bílá, 16 radius, stín; obsah: Icon | Název (tučně) | Price badge | Edit | Delete.
class _ModuleCardRow extends ConsumerWidget {
  const _ModuleCardRow({required this.module, required this.onEdit});

  final ModuleModel module;
  final void Function(ModuleModel) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferredCurrency = ref.watch(authNotifierProvider).state.preferredCurrency ?? 'CZK';
    final currencies = ref.watch(currenciesProvider).valueOrNull ?? [];
    final priceStr = module.price != null
        ? (currencies.isEmpty
            ? '${module.price!.toStringAsFixed(2)} €'
            : CurrencyService.formatPrice(module.price!.toDouble(), preferredCurrency, currencies))
        : 'super_admin.module_price_na'.tr();
    final badgeColor = _pricingTypeBadgeColor(module.pricingType);

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
          Icon(ModuleIconMapper.getIcon(module.key), size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${module.orderIndex}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              module.name,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[900], fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              getPricingTypeLabelKey(module.pricingType).tr(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(priceStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[800])),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey[700]),
            tooltip: 'settings.module_edit'.tr(),
            onPressed: () => onEdit(module),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
            tooltip: 'settings.module_delete'.tr(),
            onPressed: () => _confirmDeleteModule(context, ref, module),
          ),
        ],
      ),
    );
  }
}

/// Společná logika potvrzení a smazání modulu (používá _ModuleListRow i _ModuleCardRow).
Future<void> _confirmDeleteModule(BuildContext context, WidgetRef ref, ModuleModel module) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('settings.module_delete'.tr()),
      content: Text('settings.module_delete_confirm'.tr()),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('common.cancel'.tr())),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: Text('settings.module_delete'.tr()),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await SuperAdminService.deleteModule(module.id);
    ref.invalidate(allModulesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.module_deleted'.tr()), behavior: SnackBarBehavior.floating),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.module_delete_error'.tr(namedArgs: {'message': e.toString()})),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Bílá karta ve stylu TenantCommandModal – 24px radius, měkký stín (Apple/glassmorphism).
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  static BoxDecoration get _decoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _decoration,
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}

/// Barva badge pro typ ceny – Fixed = modrá, Per apartment = fialová, Per user = teal.
Color _pricingTypeBadgeColor(String pricingType) {
  switch (pricingType) {
    case 'per_apartment':
      return Colors.purple.shade400;
    case 'per_user':
      return Colors.teal.shade600;
    case 'fixed':
    default:
      return Colors.blue.shade600;
  }
}

/// Karta „Kurzovní lístek“ – pouze pro Super Admina.
class _ExchangeRatesCard extends ConsumerWidget {
  const _ExchangeRatesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currenciesAsync = ref.watch(currenciesProvider);

    return _SettingsCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'settings.exchange_rates'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[900],
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'settings.exchange_rates_hint'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 12),
            currenciesAsync.when(
              data: (currencies) {
                if (currencies.isEmpty) {
                  return Text(
                    'common.loading'.tr(),
                    style: TextStyle(color: Colors.grey.shade600),
                  );
                }
                return Column(
                  children: [
                    ...currencies.map(
                      (c) => _CurrencyListTile(
                        currency: c,
                        onEditRate: c.code == 'EUR'
                            ? null
                            : () => _showEditRateDialog(
                                  context,
                                  ref,
                                  c,
                                ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showAddCurrencyDialog(context, ref),
                      icon: const Icon(Icons.add, size: 20),
                      label: Text('settings.add_currency'.tr()),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (err, _) => Text(
                'common.error_with_message'.tr(namedArgs: {'message': err.toString()}),
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
    );
  }

  static Future<void> _showEditRateDialog(
    BuildContext context,
    WidgetRef ref,
    CurrencyRow currency,
  ) async {
    final controller = TextEditingController(
      text: currency.rate.toString(),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settings.edit_rate'.tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '${currency.code} (${'settings.currency_rate'.tr()})',
            border: const OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    final rate = double.tryParse(controller.text.trim());
    if (rate == null || rate <= 0) return;
    try {
      await CurrencyService.updateRate(currency.code, rate);
      ref.invalidate(currenciesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.rate_saved'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.rate_save_error'.tr(namedArgs: {'message': e.toString()})),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static Future<void> _showAddCurrencyDialog(BuildContext context, WidgetRef ref) async {
    final codeController = TextEditingController();
    final symbolController = TextEditingController();
    final rateController = TextEditingController(text: '1');
    final nameController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settings.add_currency'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'settings.currency_code'.tr(),
                  hintText: 'PLN',
                  border: const OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: symbolController,
                decoration: InputDecoration(
                  labelText: 'settings.currency_symbol'.tr(),
                  hintText: 'zł',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateController,
                decoration: InputDecoration(
                  labelText: 'settings.currency_rate'.tr(),
                  hintText: '25',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'settings.currency_name'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    final code = codeController.text.trim().toUpperCase();
    final symbol = symbolController.text.trim();
    final rate = double.tryParse(rateController.text.trim());
    if (code.isEmpty || symbol.isEmpty || rate == null || rate <= 0) return;
    try {
      await CurrencyService.insertCurrency(CurrencyRow(
        code: code,
        symbol: symbol,
        rate: rate,
        name: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
      ));
      ref.invalidate(currenciesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.currency_added'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings.rate_save_error'.tr(namedArgs: {'message': e.toString()})),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _CurrencyListTile extends StatelessWidget {
  const _CurrencyListTile({
    required this.currency,
    this.onEditRate,
  });

  final CurrencyRow currency;
  final VoidCallback? onEditRate;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text('${currency.code} ${currency.symbol}'),
      subtitle: Text(currency.name ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currency.rate.toStringAsFixed(currency.code == 'EUR' ? 0 : 2),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onEditRate != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEditRate,
              tooltip: 'settings.edit_rate'.tr(),
            ),
          ],
        ],
      ),
    );
  }
}
