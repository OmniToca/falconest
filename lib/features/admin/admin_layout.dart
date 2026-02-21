import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/admin/admin_apartments_screen.dart';
import 'package:falconest/features/admin/admin_dashboard_screen.dart';
import 'package:falconest/features/admin/admin_reservations_screen.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/admin_team_screen.dart';
import 'package:falconest/features/calendar/screens/planning_calendar_screen.dart';
import 'package:falconest/features/admin/models/module_model.dart';
import 'package:falconest/features/admin/providers/current_tenant_name_provider.dart';
import 'package:falconest/features/admin/providers/module_provider.dart';
import 'package:falconest/features/admin/utils/module_icon_mapper.dart';
import 'package:falconest/features/settings/settings_screen.dart';

/// Práh šířky v pixelech – pod ním Drawer, nad ním permanentní Sidebar.
const double _breakpointWidth = 800;

/// Indexy záložek v admin sekci – export pro dashboard (přepnutí na Rezervace/Úkoly).
const int adminTabIndexDashboard = 0;
const int adminTabIndexTeam = 1;
const int adminTabIndexApartments = 2;
const int adminTabIndexReservations = 3;
const int adminTabIndexTasks = 4;
const int adminTabIndexPlanningCalendar = 5;

/// Umožňuje přepnutí záložky z vnořených obrazovek (např. z dashboardu po kliknutí na akci).
class AdminTabScope extends InheritedWidget {
  const AdminTabScope({
    super.key,
    required this.switchToTab,
    required super.child,
  });

  final void Function(int index) switchToTab;

  static void Function(int)? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminTabScope>()?.switchToTab;
  }

  @override
  bool updateShouldNotify(AdminTabScope oldWidget) =>
      oldWidget.switchToTab != switchToTab;
}

/// Responzivní layout pro admin sekci FalcoNest.
///
/// Používá [IndexedStack] – podle [_selectedIndex] zobrazuje jednu z existujících
/// obrazovek: Nástěnka, Personál, Byty, Rezervace, Úkoly.
/// Na úzkých obrazovkách Drawer, na širokých stálý Sidebar.
class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = adminTabIndexDashboard;

  /// Tělo obsahu – IndexedStack drží všechny obrazovky, přepíná podle výběru.
  /// Zachovává stav při přepnutí záložky (scroll, formuláře).
  static final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const AdminTeamScreen(),
    const AdminApartmentsScreen(),
    const AdminReservationsScreen(),
    const AdminTasksScreen(),
    const PlanningCalendarScreen(),
  ];

  void _switchToTab(int index) {
    setState(() => _selectedIndex = index.clamp(0, _screens.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return AdminTabScope(
      switchToTab: _switchToTab,
      child: Consumer(
        builder: (context, ref, _) {
          final auth = ref.watch(authNotifierProvider);
          final isImpersonating = auth.state.isImpersonating;
          // Super Admin smí na /admin jen s vybranou agenturou – jinak přesměrovat na přehled.
          if (auth.state.role == 'super_admin' && auth.tenantIdForData == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/super-admin');
            });
            return const Center(child: CircularProgressIndicator());
          }
          final tenantNameAsync = ref.watch(currentTenantNameProvider);
          final tenantName = tenantNameAsync.valueOrNull ?? '';
          final announcementAsync = ref.watch(currentTenantAnnouncementProvider);
          final announcement = announcementAsync.valueOrNull;
          // Drží stav tenanta včetně Realtime – aby se provider budoval a naslouchal změnám.
          ref.watch(currentTenantWithRealtimeProvider);
          // Okamžitý vyhazovač: když je tenant vypnut (is_active == false) a nejde o převtělení.
          ref.listen<AsyncValue<CurrentTenantDetail?>>(
            currentTenantWithRealtimeProvider,
            (previous, next) {
              final tenant = next.valueOrNull;
              if (tenant != null &&
                  tenant.isActive == false &&
                  !isImpersonating &&
                  context.mounted) {
                context.go('/suspended');
              }
            },
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _breakpointWidth;
              final body = isWide
                  ? _WideLayout(
                      selectedIndex: _selectedIndex,
                      onIndexChanged: (i) => setState(() => _selectedIndex = i),
                      body: IndexedStack(
                        index: _selectedIndex.clamp(0, _screens.length - 1),
                        children: _screens,
                      ),
                    )
                  : _NarrowLayout(
                      selectedIndex: _selectedIndex,
                      onIndexChanged: (i) => setState(() => _selectedIndex = i),
                      body: IndexedStack(
                        index: _selectedIndex.clamp(0, _screens.length - 1),
                        children: _screens,
                      ),
                    );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isImpersonating)
                    _ImpersonationBanner(
                      tenantName: tenantName,
                      onStop: () async {
                        await auth.stopImpersonating();
                        if (context.mounted) context.go('/super-admin');
                      },
                    ),
                  if (announcement != null && announcement.isNotEmpty)
                    _SystemAnnouncementBanner(message: announcement),
                  Expanded(child: body),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Varovný pruh režimu převtělení – zobrazuje se ÚPLNĚ NAHOŘE, nesmí mizet při scrollování.
/// Pozadí výrazné (deepOrange), text bílý, název agentury tučně.
class _ImpersonationBanner extends StatelessWidget {
  const _ImpersonationBanner({
    required this.tenantName,
    required this.onStop,
  });

  final String tenantName;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final template = 'admin.impersonation_agency'.tr();
    const placeholder = '{name}';
    final idx = template.indexOf(placeholder);
    Widget textWidget;
    if (idx >= 0) {
      final before = template.substring(0, idx);
      final after = template.substring(idx + placeholder.length);
      textWidget = Text.rich(
        TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          children: [
            TextSpan(text: before),
            TextSpan(
              text: tenantName.isNotEmpty ? tenantName : '…',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: after),
          ],
        ),
      );
    } else {
      textWidget = Text(
        tenantName.isNotEmpty
            ? template.replaceAll(placeholder, tenantName)
            : template,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.deepOrange,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(child: textWidget),
            const SizedBox(width: 16),
            TextButton(
              onPressed: onStop,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              child: Text('admin.impersonation_stop'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pruh s oznámením systému (Megafon) – modré pozadí, bílý text, ikona campaign.
class _SystemAnnouncementBanner extends StatelessWidget {
  const _SystemAnnouncementBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = 'admin.system_announcement_label'.tr(namedArgs: {'message': message});
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.blue.shade700,
      child: Row(
        children: [
          Icon(Icons.campaign, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Layout pro široké obrazovky – stálý Sidebar + IndexedStack s obsahem.
class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.body,
  });

  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _AdminSidebar(
            isDrawer: false,
            selectedIndex: selectedIndex,
            onIndexChanged: onIndexChanged,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Layout pro úzké obrazovky – AppBar s hamburgerem + Drawer.
class _NarrowLayout extends ConsumerWidget {
  const _NarrowLayout({
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.body,
  });

  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final isImpersonating = auth.state.isImpersonating;

    return Scaffold(
      appBar: AppBar(
        title: Text('admin.title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        actions: [
          IconButton(
            icon: Icon(isImpersonating ? Icons.arrow_back : Icons.logout),
            tooltip: isImpersonating
                ? 'admin.back_to_command_center'.tr()
                : 'admin.menu_logout'.tr(),
            onPressed: () async {
              if (isImpersonating) {
                await auth.stopImpersonating();
                if (context.mounted) context.go('/super-admin');
              } else {
                await SupabaseService.client.auth.signOut();
                if (context.mounted) context.go('/');
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: _AdminSidebar(
          isDrawer: true,
          selectedIndex: selectedIndex,
          onIndexChanged: onIndexChanged,
        ),
      ),
      body: body,
    );
  }
}

/// Postranní panel s menu – položky z katalogu modulů (SaaS menu).
/// Aktivní moduly jsou klikatelné, neaktivní zobrazeny jako zamčené (🔒) s toastem.
class _AdminSidebar extends ConsumerWidget {
  const _AdminSidebar({
    required this.isDrawer,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  final bool isDrawer;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(allModulesProvider);
    final activeKeysAsync = ref.watch(activeModuleKeysProvider);
    final isSuperAdmin = ref.watch(authNotifierProvider).state.role == 'super_admin';
    final activeKeys = activeKeysAsync.valueOrNull ?? {};
    final rawModules = modulesAsync.valueOrNull;
    final allModules = (rawModules == null || rawModules.isEmpty)
        ? _fallbackModules()
        : rawModules;
    final visibleModules = allModules.where((m) => m.showInMenu).toList();

    return SafeArea(
      child: SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isDrawer)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'admin.title'.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            const Divider(height: 1),
            if (modulesAsync.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else
              ...visibleModules.map((module) {
                final tenantHasModule = activeKeys.contains(module.key);
                final isActive = isSuperAdmin || tenantHasModule;
                final isGhost = isSuperAdmin && !tenantHasModule;
                final tabIndex = ModuleIconMapper.getTabIndex(module.key);
                final label = ModuleIconMapper.getLabelKey(module.key).tr();
                return _ModuleNavItem(
                  module: module,
                  label: label,
                  isActive: isActive,
                  isGhost: isGhost,
                  selectedIndex: selectedIndex,
                  isDrawer: isDrawer,
                  onTapActive: () {
                    if (isDrawer && Scaffold.maybeOf(context)?.isDrawerOpen == true) {
                      Navigator.of(context).pop();
                    }
                    if (tabIndex != null) {
                      onIndexChanged(tabIndex.clamp(0, adminTabIndexPlanningCalendar));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label – ${'admin.module_coming_soon'.tr()}'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  onTapLocked: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('admin.module_locked_toast'.tr(namedArgs: {'name': label})),
                        backgroundColor: Colors.orange.shade800,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.settings, size: 22),
              title: Text('settings.menu_settings'.tr()),
              onTap: () {
                if (isDrawer && Scaffold.maybeOf(context)?.isDrawerOpen == true) {
                  Navigator.of(context).pop();
                }
                SettingsModal.show(context);
              },
            ),
            const _LogoutTile(),
          ],
        ),
      ),
    );
  }

  static List<ModuleModel> _fallbackModules() {
    const keys = ['dashboard', 'staff', 'apartments', 'reservations', 'tasks'];
    return [for (var i = 0; i < keys.length; i++) ModuleModel(id: keys[i], key: keys[i], name: keys[i], sortOrder: i)];
  }
}

/// Jedna položka menu modulu – aktivní (klikatelná), „ghost“ (jen pro admina), nebo zamčená (šedá + 🔒).
/// [isGhost]: true = tenant modul nemá, ale super admin ho vidí – vizuální odlišení (oranžová/šedá + badge + tooltip).
class _ModuleNavItem extends StatelessWidget {
  const _ModuleNavItem({
    required this.module,
    required this.label,
    required this.isActive,
    required this.isGhost,
    required this.selectedIndex,
    required this.isDrawer,
    required this.onTapActive,
    required this.onTapLocked,
  });

  final ModuleModel module;
  final String label;
  final bool isActive;
  final bool isGhost;
  final int selectedIndex;
  final bool isDrawer;
  final VoidCallback onTapActive;
  final VoidCallback onTapLocked;

  @override
  Widget build(BuildContext context) {
    final tabIndex = ModuleIconMapper.getTabIndex(module.key);
    final selected = isActive && tabIndex != null && tabIndex == selectedIndex;
    final icon = ModuleIconMapper.getIcon(module.key);
    final primary = Theme.of(context).colorScheme.primary;
    final muted = Colors.grey.shade600;
    final ghostColor = Colors.orange.shade700;

    if (isActive) {
      final titleColor = isGhost ? ghostColor : (selected ? primary : null);
      final titleWidget = Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: titleColor ?? Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isGhost)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.visibility_off, size: 14, color: ghostColor),
            ),
        ],
      );
      final tile = ListTile(
        leading: Icon(icon, color: selected ? primary : (isGhost ? ghostColor : null), size: 22),
        title: titleWidget,
        onTap: onTapActive,
      );
      return isGhost
          ? Tooltip(
              message: 'admin.module_ghost_tooltip'.tr(),
              child: tile,
            )
          : tile;
    }

    return ListTile(
      leading: Icon(icon, color: muted, size: 22),
      title: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: muted, fontSize: 15),
            ),
          ),
          Icon(Icons.lock_outline, size: 16, color: muted),
        ],
      ),
      onTap: onTapLocked,
    );
  }
}

/// Tlačítko Odhlásit se, nebo „Zpět do Velína“ při režimu převtělení.
class _LogoutTile extends ConsumerWidget {
  const _LogoutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final isImpersonating = auth.state.isImpersonating;

    if (isImpersonating) {
      return ListTile(
        leading: Icon(Icons.arrow_back, color: Colors.orange.shade700, size: 22),
        title: Text(
          'admin.back_to_command_center'.tr(),
          style: TextStyle(
            fontSize: 15,
            color: Colors.orange.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () async {
          if (Scaffold.of(context).isDrawerOpen) {
            Navigator.of(context).pop();
          }
          await auth.stopImpersonating();
          if (context.mounted) context.go('/super-admin');
        },
      );
    }

    return ListTile(
      leading: Icon(Icons.logout, color: Colors.red.shade400, size: 22),
      title: Text(
        'admin.menu_logout'.tr(),
        style: TextStyle(
          fontSize: 15,
          color: Colors.red.shade400,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () async {
        if (Scaffold.of(context).isDrawerOpen) {
          Navigator.of(context).pop();
        }
        await SupabaseService.client.auth.signOut();
        if (context.mounted) context.go('/');
      },
    );
  }
}
