import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/owner/owner_apartments_screen.dart';
import 'package:falconest/features/owner/owner_billing_screen.dart';
import 'package:falconest/features/owner/owner_dashboard_screen.dart';
import 'package:falconest/features/owner/owner_planning_calendar_screen.dart';
import 'package:falconest/features/owner/owner_reservations_screen.dart';
import 'package:falconest/features/owner/owner_tasks_screen.dart';

/// Práh šířky v pixelech – pod ním Drawer, nad ním permanentní Sidebar.
const double _breakpointWidth = 800;

/// Jemné barvy pro prémiový design – světlé pozadí, tlumené akcenty.
const _panelBg = Color(0xFFFAFAFA);
const _surfaceBg = Color(0xFFFFFFFF);
const _accentColor = Color(0xFF1976D2);
const _textMuted = Color(0xFF616161);

/// Indexy záložek v klientském portálu.
const int _ownerTabDashboard = 0;
const int _ownerTabApartments = 1;
const int _ownerTabReservations = 2;
const int _ownerTabTasks = 3;
const int _ownerTabCalendar = 4;
const int _ownerTabBilling = 5;

/// Responzivní layout pro klientský portál majitelů bytů (role property_owner).
///
/// REFACTOR: Přechod z ShellRoute na IndexedStack pro stabilnější navigaci v Klientském portálu.
/// Používá lokální stav (_selectedIndex) místo GoRouter pro přepínání záložek – stejný princip jako Admin.
///
/// [initialTabIndex] – výchozí záložka (např. při deeplinku `/owner/dashboard`).
///
/// Pomocí [LayoutBuilder] mění chování podle šířky obrazovky:
/// - **Úzké (< 800 px)**: Vysouvací [Drawer] s hamburger ikonou v AppBar
/// - **Široké (>= 800 px)**: Stálý levý postranní panel vedle obsahu
///
/// Prémiový design: více whitespace, jemné stíny, zakulacené rohy.
class OwnerLayout extends StatefulWidget {
  const OwnerLayout({
    super.key,
    this.initialTabIndex = _ownerTabDashboard,
  });

  /// Výchozí záložka (0 = Dashboard, 1 = Apartmány, …).
  final int initialTabIndex;

  @override
  State<OwnerLayout> createState() => _OwnerLayoutState();
}

class _OwnerLayoutState extends State<OwnerLayout> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex.clamp(
      _ownerTabDashboard,
      _ownerTabBilling,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _selectedIndex,
      children: const [
        OwnerDashboardScreen(),
        OwnerApartmentsScreen(),
        OwnerReservationsScreen(),
        OwnerTasksScreen(),
        OwnerPlanningCalendarScreen(),
        OwnerBillingScreen(),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _breakpointWidth;
        return isWide
            ? _WideLayout(
                body: body,
                onIndexChanged: (i) => setState(() => _selectedIndex = i),
              )
            : _NarrowLayout(
                body: body,
                onIndexChanged: (i) => setState(() => _selectedIndex = i),
              );
      },
    );
  }
}

/// Layout pro široké obrazovky – stálý Sidebar + obsah.
class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.body, required this.onIndexChanged});

  final Widget body;
  final void Function(int index) onIndexChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceBg,
      body: Row(
        children: [
          _OwnerSidebar(isDrawer: false, onIndexChanged: onIndexChanged),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Layout pro úzké obrazovky – AppBar s hamburgerem + Drawer.
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.body, required this.onIndexChanged});

  final Widget body;
  final void Function(int index) onIndexChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceBg,
      appBar: AppBar(
        title: Text('owner.layout_title'.tr()),
        backgroundColor: _surfaceBg,
        foregroundColor: _accentColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      drawer: Drawer(
          child: _OwnerSidebar(isDrawer: true, onIndexChanged: onIndexChanged)),
      body: body,
    );
  }
}

/// Postranní panel s menu – použit jako Drawer i jako Sidebar.
///
/// Obsahuje uvítání, navigační položky a odhlášení. Prémiový vzhled
/// s většími odsazeními a jemnými stíny.
/// Volá [onIndexChanged] místo context.go – přepíná záložky lokálním setState.
class _OwnerSidebar extends StatelessWidget {
  const _OwnerSidebar({
    required this.isDrawer,
    required this.onIndexChanged,
  });

  final bool isDrawer;
  final void Function(int index) onIndexChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _panelBg,
      child: SafeArea(
        child: SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Uvítání nahoře
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Text(
                  'owner.welcome_owner'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _accentColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const Divider(height: 1, indent: 24, endIndent: 24),
              const SizedBox(height: 16),
              // Navigační položky – Přepnutí záložky přes setState (IndexedStack).
              _OwnerNavItem(
                icon: Icons.dashboard_outlined,
                label: 'owner.menu_dashboard'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(_ownerTabDashboard),
              ),
              _OwnerNavItem(
                icon: Icons.apartment_outlined,
                label: 'owner.menu_apartments'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(_ownerTabApartments),
              ),
              _OwnerNavItem(
                icon: Icons.calendar_today_outlined,
                label: 'owner.menu_reservations'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(_ownerTabReservations),
              ),
              _OwnerNavItem(
                icon: Icons.task_alt,
                label: 'owner.menu_tasks'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(_ownerTabTasks),
              ),
              _OwnerNavItem(
                icon: Icons.calendar_month,
                label: 'owner.menu_calendar'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(_ownerTabCalendar),
              ),
              _OwnerNavItem(
                icon: Icons.receipt_long,
                label: 'owner.menu_billing'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(_ownerTabBilling),
              ),
              const Spacer(),
              const Divider(height: 1, indent: 24, endIndent: 24),
              const SizedBox(height: 8),
              // Odhlásit se – oddělené dole
              _LogoutTile(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Položka navigace – jemnější design s větším paddingem.
/// Volá [onTap] – lokální přepnutí záložky, ne context.go.
class _OwnerNavItem extends StatelessWidget {
  const _OwnerNavItem({
    required this.icon,
    required this.label,
    required this.isDrawer,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDrawer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(icon, color: _accentColor, size: 22),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: _textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: () {
            // Na úzkých obrazovkách nejprve zavřeme Drawer, pak přepneme záložku.
            if (isDrawer && Scaffold.maybeOf(context)?.isDrawerOpen == true) {
              Navigator.of(context).pop();
            }
            onTap();
          },
        ),
      ),
    );
  }
}

/// Tlačítko Odhlásit se – volá Supabase signOut a smaže session.
///
/// Po odhlášení AuthNotifier automaticky upozorní GoRouter redirect,
/// který uživatele přesměruje na login.
class _LogoutTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(Icons.logout, color: Colors.red.shade400, size: 22),
        title: Text(
          'owner.menu_logout'.tr(),
          style: TextStyle(
            fontSize: 15,
            color: Colors.red.shade400,
            fontWeight: FontWeight.w600,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () async {
          if (Scaffold.of(context).isDrawerOpen) {
            Navigator.of(context).pop();
          }
          await SupabaseService.client.auth.signOut();
          if (context.mounted) {
            context.go('/');
          }
        },
      ),
    );
  }
}
