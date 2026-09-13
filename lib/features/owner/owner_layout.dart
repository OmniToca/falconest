import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/features/owner/owner_apartments_screen.dart';
import 'package:falconest/features/owner/owner_billing_screen.dart';
import 'package:falconest/features/owner/owner_dashboard_screen.dart';
import 'package:falconest/features/owner/owner_planning_calendar_screen.dart';
import 'package:falconest/features/owner/owner_portal_tabs.dart';
import 'package:falconest/features/owner/owner_reservations_screen.dart';
import 'package:falconest/features/owner/owner_settings_screen.dart';
import 'package:falconest/features/owner/owner_tasks_screen.dart';
import 'package:falconest/features/owner/providers/owner_cash_providers.dart';
import 'package:falconest/core/auth/owner_view_impersonation_providers.dart';
import 'package:falconest/core/widgets/lazy_indexed_stack.dart';
import 'package:falconest/features/owner/widgets/owner_view_impersonation_banner.dart';

/// Práh šířky v pixelech – pod ním Drawer, nad ním permanentní Sidebar.
const double _breakpointWidth = 800;

/// Poloměr „pilulky“ u aktivní / hover položky menu – vizuálně shodný s kartami portálu.
const double _ownerNavItemRadius = 12;

/// Responzivní layout pro klientský portál majitelů bytů (role property_owner).
///
/// REFACTOR: Přechod z ShellRoute na [LazyIndexedStack] pro stabilnější navigaci v Klientském portálu.
/// Používá lokální stav (_selectedIndex) místo GoRouter pro přepínání záložek – stejný princip jako Admin.
///
/// [initialTabIndex] – výchozí záložka (např. při deeplinku `/owner/dashboard`).
///
/// Pomocí [LayoutBuilder] mění chování podle šířky obrazovky:
/// - **Úzké (< 800 px)**: Vysouvací [Drawer] s hamburger ikonou v AppBar
/// - **Široké (>= 800 px)**: Stálý levý postranní panel vedle obsahu
///
/// Vizuální jazyk: barvy z [ColorScheme] (surface / surfaceContainer*), aktivní záložka
/// se zvýrazní zakulaceným [primaryContainer] – bez vlastních hex barev mimo téma.
class OwnerLayout extends ConsumerStatefulWidget {
  const OwnerLayout({
    super.key,
    this.initialTabIndex = OwnerPortalTabIndex.dashboard,
  });

  /// Výchozí záložka (0 = Dashboard, 1 = Apartmány, …).
  final int initialTabIndex;

  @override
  ConsumerState<OwnerLayout> createState() => _OwnerLayoutState();
}

class _OwnerLayoutState extends ConsumerState<OwnerLayout> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex.clamp(
      OwnerPortalTabIndex.dashboard,
      OwnerPortalTabIndex.settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(ownerPortalTabIndexRequestProvider, (previous, next) {
      if (next == null) return;
      final i = next.clamp(OwnerPortalTabIndex.dashboard, OwnerPortalTabIndex.settings);
      setState(() => _selectedIndex = i);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(ownerPortalTabIndexRequestProvider.notifier).state = null;
      });
    });

    final body = LazyIndexedStack(
      index: _selectedIndex,
      children: const [
        OwnerDashboardScreen(),
        OwnerApartmentsScreen(),
        OwnerReservationsScreen(),
        OwnerTasksScreen(),
        OwnerPlanningCalendarScreen(),
        OwnerBillingScreen(),
        OwnerSettingsScreen(),
      ],
    );

    final isOwnerView = ref.watch(isOwnerViewReadOnlyProvider);
    final ownerViewInfo = ref.watch(ownerViewImpersonationInfoProvider);

    final layout = LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _breakpointWidth;
        return isWide
            ? _WideLayout(
                body: body,
                selectedIndex: _selectedIndex,
                onIndexChanged: (i) => setState(() => _selectedIndex = i),
              )
            : _NarrowLayout(
                body: body,
                selectedIndex: _selectedIndex,
                onIndexChanged: (i) => setState(() => _selectedIndex = i),
              );
      },
    );

    if (!isOwnerView) {
      return layout;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OwnerViewImpersonationBanner(
          displayName: ownerViewInfo.displayName ?? '',
          onStop: () => returnFromOwnerView(context, ref),
        ),
        Expanded(child: layout),
      ],
    );
  }
}

/// Layout pro široké obrazovky – stálý Sidebar + obsah.
class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.body,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  final Widget body;
  final int selectedIndex;
  final void Function(int index) onIndexChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Row(
        children: [
          _OwnerSidebar(
            isDrawer: false,
            selectedIndex: selectedIndex,
            onIndexChanged: onIndexChanged,
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Layout pro úzké obrazovky – AppBar s hamburgerem + Drawer.
///
/// PROČ: Na mobilu/tabletu v portrait nedává smysl permanentní sidebar; Drawer
/// šetří šířku a zachovává stejné menu jako na desktopu.
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.body,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  final Widget body;
  final int selectedIndex;
  final void Function(int index) onIndexChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          'owner.layout_title'.tr(),
          style: tt.titleLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: cs.surfaceContainerLow,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu_rounded, color: cs.primary),
            tooltip: MaterialLocalizations.of(ctx).openAppDrawerTooltip,
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        child: _OwnerSidebar(
          isDrawer: true,
          selectedIndex: selectedIndex,
          onIndexChanged: onIndexChanged,
        ),
      ),
      body: body,
    );
  }
}

/// Postranní panel s menu – použit jako Drawer i jako Sidebar.
///
/// Obsahuje uvítání, navigační položky a odhlášení. Pozadí z [ColorScheme.surfaceContainerLow],
/// aby panel jemně kontrastoval s hlavní [surface] a ladil s Material 3 portálem.
/// Volá [onIndexChanged] místo context.go – přepíná záložky lokálním setState.
class _OwnerSidebar extends StatelessWidget {
  const _OwnerSidebar({
    required this.isDrawer,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  final bool isDrawer;
  final int selectedIndex;
  final void Function(int index) onIndexChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surfaceContainerLow,
      child: SafeArea(
        child: SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Text(
                  'owner.welcome_owner'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                        letterSpacing: 0.2,
                      ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                indent: 20,
                endIndent: 20,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              _OwnerNavItem(
                index: OwnerPortalTabIndex.dashboard,
                selectedIndex: selectedIndex,
                icon: Icons.dashboard_outlined,
                label: 'owner.menu_dashboard'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(OwnerPortalTabIndex.dashboard),
              ),
              _OwnerNavItem(
                index: OwnerPortalTabIndex.apartments,
                selectedIndex: selectedIndex,
                icon: Icons.apartment_outlined,
                label: 'owner.menu_apartments'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(OwnerPortalTabIndex.apartments),
              ),
              _OwnerNavItem(
                index: OwnerPortalTabIndex.reservations,
                selectedIndex: selectedIndex,
                icon: Icons.calendar_today_outlined,
                label: 'owner.menu_reservations'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(OwnerPortalTabIndex.reservations),
              ),
              _OwnerNavItem(
                index: OwnerPortalTabIndex.tasks,
                selectedIndex: selectedIndex,
                icon: Icons.task_alt_outlined,
                label: 'owner.menu_tasks'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(OwnerPortalTabIndex.tasks),
              ),
              _OwnerNavItem(
                index: OwnerPortalTabIndex.calendar,
                selectedIndex: selectedIndex,
                icon: Icons.calendar_month_outlined,
                label: 'owner.menu_calendar'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(OwnerPortalTabIndex.calendar),
              ),
              _OwnerNavItem(
                index: OwnerPortalTabIndex.billing,
                selectedIndex: selectedIndex,
                icon: Icons.receipt_long_outlined,
                label: 'owner.menu_billing'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(OwnerPortalTabIndex.billing),
              ),
              _OwnerNavItem(
                index: OwnerPortalTabIndex.settings,
                selectedIndex: selectedIndex,
                icon: Icons.settings_outlined,
                label: 'owner.menu_settings'.tr(),
                isDrawer: isDrawer,
                onTap: () => onIndexChanged(OwnerPortalTabIndex.settings),
              ),
              const Spacer(),
              Divider(
                height: 1,
                thickness: 1,
                indent: 20,
                endIndent: 20,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 6),
              _LogoutTile(isDrawer: isDrawer),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Položka navigace – zakulacené pozadí při výběru (primaryContainer), ikony outlined.
class _OwnerNavItem extends StatelessWidget {
  const _OwnerNavItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    required this.isDrawer,
    required this.onTap,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final String label;
  final bool isDrawer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final selected = index == selectedIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_ownerNavItemRadius),
          onTap: () {
            if (isDrawer && Scaffold.maybeOf(context)?.isDrawerOpen == true) {
              Navigator.of(context).pop();
            }
            onTap();
          },
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? cs.primaryContainer.withValues(alpha: 0.55)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(_ownerNavItemRadius),
              border: Border.all(
                color: selected
                    ? cs.primary.withValues(alpha: 0.22)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: tt.bodyLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
  const _LogoutTile({required this.isDrawer});

  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_ownerNavItemRadius),
          onTap: () async {
            if (isDrawer && Scaffold.maybeOf(context)?.isDrawerOpen == true) {
              Navigator.of(context).pop();
            }
            await SupabaseService.client.auth.signOut();
            if (context.mounted) {
              context.go('/');
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.logout_rounded, color: cs.error, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'owner.menu_logout'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          color: cs.error,
                          fontWeight: FontWeight.w600,
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
}
