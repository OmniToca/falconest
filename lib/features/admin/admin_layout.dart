import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/models/notification_model.dart';
import 'package:falconest/core/providers/notification_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/settings/providers/profile_provider.dart';
import 'package:falconest/features/admin/admin_apartments_screen.dart';
import 'package:falconest/features/admin/admin_dashboard_screen.dart';
import 'package:falconest/features/admin/admin_reservations_screen.dart';
import 'package:falconest/features/admin/admin_tasks_screen.dart';
import 'package:falconest/features/admin/admin_team_screen.dart';
import 'package:falconest/features/admin/finance_dashboard_screen.dart';
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
const int adminTabIndexFinance = 6;

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

  /// Stav kolapsu levého menu – true = zobrazeno, false = skryto (široký layout).
  bool _isSidebarOpen = true;

  /// Tělo obsahu – IndexedStack drží všechny obrazovky, přepíná podle výběru.
  /// Zachovává stav při přepnutí záložky (scroll, formuláře).
  static final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const AdminTeamScreen(),
    const AdminApartmentsScreen(),
    const AdminReservationsScreen(),
    const AdminTasksScreen(),
    const PlanningCalendarScreen(),
    const FinanceDashboardScreen(),
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
                      isSidebarOpen: _isSidebarOpen,
                      onSidebarToggle: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
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

/// Zvoneček s Badge – poslouchá Realtime stream nepřečtených notifikací.
///
/// PROČ: Zde posloucháme Realtime stream ze Supabase. Jakmile uklízečka v terénu
/// vygeneruje alert, UI se okamžitě překreslí díky Riverpod streamu.
class _NotificationsBell extends ConsumerWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadNotificationsProvider);
    final notifications = unreadAsync.valueOrNull ?? [];
    final count = notifications.length;

    Widget icon = Icon(Icons.notifications_none_outlined);
    if (count > 0) {
      icon = Badge(
        label: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        child: icon,
      );
    }

    return IconButton(
      icon: icon,
      onPressed: () => _NotificationsPanelDialog.show(context),
      tooltip: 'admin.topbar_notifications'.tr(),
    );
  }
}

/// Dialog s panelem nepřečtených notifikací – Realtime aktualizace při markAsRead.
///
/// Po kliknutí na položku se zavolá markAsRead(id), stream se aktualizuje a položka vizuálně zmizí.
class _NotificationsPanelDialog extends ConsumerWidget {
  const _NotificationsPanelDialog();

  static void show(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _NotificationsPanelDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadNotificationsProvider);
    final notifications = unreadAsync.valueOrNull ?? [];
    final repository = ref.read(notificationRepositoryProvider);

    return AlertDialog(
      title: Text('admin.notifications_title'.tr()),
      content: SizedBox(
        width: 340,
        child: unreadAsync.isLoading
            ? const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            : notifications.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'admin.notifications_empty'.tr(),
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        return _NotificationTile(
                          notification: n,
                          onTap: () async {
                            await repository.markAsRead(n.id);
                          },
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

/// Jedna položka v seznamu notifikací – title (tučně), message (šedě), čas.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeStr = notification.createdAt != null
        ? DateFormat('d.M. HH:mm').format(notification.createdAt!.toLocal())
        : '—';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
              if (notification.message.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Globální Top Bar (header) – hamburger pro sidebar, ikony kalendář/notifikace, profil s PopupMenu.
class _AdminTopBar extends ConsumerWidget {
  const _AdminTopBar({required this.onMenuTap});

  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.valueOrNull;
    final role = auth.state.role;
    final isImpersonating = auth.state.isImpersonating;

    final displayName = (profile?.name ?? '').trim().isNotEmpty
        ? profile!.name
        : (profile?.email ?? '').split('@').first;
    final initials = _initials(displayName, profile?.email ?? '');

    final roleLabel = _roleLabel(context, role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onMenuTap,
              tooltip: 'admin.topbar_menu'.tr(),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: () {
                AdminTabScope.of(context)?.call(adminTabIndexPlanningCalendar);
              },
              tooltip: 'admin.topbar_calendar'.tr(),
            ),
            _NotificationsBell(),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              offset: const Offset(0, 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isNotEmpty ? displayName : '—',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          roleLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 20, color: Colors.grey.shade700),
                      const SizedBox(width: 12),
                      Text('settings.menu_settings'.tr()),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: isImpersonating ? 'back' : 'logout',
                  child: Row(
                    children: [
                      Icon(
                        isImpersonating ? Icons.arrow_back : Icons.logout,
                        size: 20,
                        color: isImpersonating
                            ? Colors.orange.shade700
                            : Colors.red.shade700,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isImpersonating
                            ? 'admin.back_to_command_center'.tr()
                            : 'admin.menu_logout'.tr(),
                        style: TextStyle(
                          color: isImpersonating
                              ? Colors.orange.shade700
                              : Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'settings') {
                  SettingsModal.show(context);
                } else if (value == 'back') {
                  await auth.stopImpersonating();
                  if (context.mounted) context.go('/super-admin');
                } else if (value == 'logout') {
                  await SupabaseService.client.auth.signOut();
                  if (context.mounted) context.go('/');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name, String email) {
    if (name.isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final a = parts.first.isNotEmpty ? parts.first[0] : '';
        final b = parts.last.isNotEmpty ? parts.last[0] : '';
        return '${a.toUpperCase()}${b.toUpperCase()}';
      }
      return name.substring(0, 1).toUpperCase();
    }
    if (email.isNotEmpty) {
      return email.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  String _roleLabel(BuildContext context, String? role) {
    if (role == null || role.isEmpty) return 'settings.profile_tenant_none'.tr();
    final key = 'settings.profile_role_${role.toLowerCase()}';
    final translated = key.tr();
    return translated != key ? translated : role;
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

/// Layout pro široké obrazovky – Sidebar (skrývání) + Top Bar + IndexedStack s obsahem.
class _WideLayout extends ConsumerWidget {
  const _WideLayout({
    required this.isSidebarOpen,
    required this.onSidebarToggle,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.body,
  });

  final bool isSidebarOpen;
  final VoidCallback onSidebarToggle;
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          if (isSidebarOpen)
            _AdminSidebar(
              isDrawer: false,
              selectedIndex: selectedIndex,
              onIndexChanged: onIndexChanged,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminTopBar(
                  onMenuTap: onSidebarToggle,
                ),
                Expanded(child: body),
              ],
            ),
          ),
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
            icon: const Icon(Icons.settings),
            tooltip: 'settings.menu_settings'.tr(),
            onPressed: () => SettingsModal.show(context),
          ),
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
        backgroundColor: Theme.of(context).colorScheme.primary,
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
    final financeActive = isModuleActive(ref, 'finance');
    final visibleModules = allModules.where((m) {
      if (!m.showInMenu) return false;
      if (m.key == 'finance' && !financeActive) return false;
      return true;
    }).toList();

    final tenantName = ref.watch(currentTenantNameProvider).valueOrNull ?? '';
    final headerTitle = tenantName.trim().isNotEmpty ? tenantName : 'admin.title'.tr();
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Container(
        width: 240,
        color: primaryColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hlavička s brandem agentury – název tenantů, pod ním "Powered by FalcoNest"
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headerTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'admin.sidebar_powered_by'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 32),
            if (modulesAsync.isLoading)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                ),
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
                      onIndexChanged(tabIndex.clamp(0, adminTabIndexFinance));
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
/// Tmavý sidebar: světlé texty/ikony (white70/white), aktivní položka má bílý text + jemné pozadí.
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
    // Tmavý sidebar – světlé barvy pro čitelnost
    const normalColor = Colors.white70;
    const selectedColor = Colors.white;
    final ghostColor = Colors.orange.shade300;
    const lockedColor = Colors.white38;

    if (isActive) {
      final textColor = isGhost ? ghostColor : (selected ? selectedColor : normalColor);
      final iconColor = isGhost ? ghostColor : (selected ? selectedColor : normalColor);
      final titleWidget = Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: textColor,
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
        leading: Icon(icon, color: iconColor, size: 22),
        title: titleWidget,
        onTap: onTapActive,
      );
      final wrapped = isGhost
          ? Tooltip(
              message: 'admin.module_ghost_tooltip'.tr(),
              child: tile,
            )
          : tile;
      // Aktivní položka: jemné pozadí + zaoblené rohy pro výraznou vizuální odezvu
      if (selected && !isGhost) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: wrapped,
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: wrapped,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: lockedColor, size: 22),
        title: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: lockedColor, fontSize: 15),
              ),
            ),
            Icon(Icons.lock_outline, size: 16, color: lockedColor),
          ],
        ),
        onTap: onTapLocked,
      ),
    );
  }
}
