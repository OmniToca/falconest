import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:falconest/core/services/supabase_service.dart';

/// Práh šířky v pixelech – pod ním Drawer, nad ním permanentní Sidebar.
const double _breakpointWidth = 800;

/// Jemné barvy pro prémiový design – světlé pozadí, tlumené akcenty.
const _panelBg = Color(0xFFFAFAFA);
const _surfaceBg = Color(0xFFFFFFFF);
const _accentColor = Color(0xFF1976D2);
const _textMuted = Color(0xFF616161);

/// Responzivní layout pro klientský portál majitelů bytů (role property_owner).
///
/// Pomocí [LayoutBuilder] mění chování podle šířky obrazovky:
/// - **Úzké (< 800 px)**: Vysouvací [Drawer] s hamburger ikonou v AppBar
/// - **Široké (>= 800 px)**: Stálý levý postranní panel vedle obsahu
///
/// Prémiový design: více whitespace, jemné stíny, zakulacené rohy.
class OwnerLayout extends StatelessWidget {
  const OwnerLayout({super.key, required this.child});

  /// Hlavní obsah – widget vrácený vnořenou route.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _breakpointWidth;
        return isWide ? _WideLayout(child: child) : _NarrowLayout(child: child);
      },
    );
  }
}

/// Layout pro široké obrazovky – stálý Sidebar + obsah.
class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceBg,
      body: Row(
        children: [
          _OwnerSidebar(isDrawer: false),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Layout pro úzké obrazovky – AppBar s hamburgerem + Drawer.
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.child});

  final Widget child;

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
      drawer: Drawer(child: _OwnerSidebar(isDrawer: true)),
      body: child,
    );
  }
}

/// Postranní panel s menu – použit jako Drawer i jako Sidebar.
///
/// Obsahuje uvítání, navigační položky a odhlášení. Prémiový vzhled
/// s většími odsazeními a jemnými stíny.
class _OwnerSidebar extends StatelessWidget {
  const _OwnerSidebar({required this.isDrawer});

  final bool isDrawer;

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
              // Navigační položky
              _OwnerNavItem(
                icon: Icons.apartment_outlined,
                label: 'owner.menu_apartments'.tr(),
                path: '/owner/apartments',
              ),
              _OwnerNavItem(
                icon: Icons.calendar_today_outlined,
                label: 'owner.menu_reservations'.tr(),
                path: '/owner/reservations',
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
class _OwnerNavItem extends StatelessWidget {
  const _OwnerNavItem({
    required this.icon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final String label;
  final String path;

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
            if (Scaffold.of(context).isDrawerOpen) {
              Navigator.of(context).pop();
            }
            context.go(path);
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
