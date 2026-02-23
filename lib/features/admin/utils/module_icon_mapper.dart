import 'package:flutter/material.dart';

/// Mapování klíčů modulů na ikony a lokalizační klíče pro menu.
///
/// DB má pouze string klíče (např. 'finance', 'warehouse', 'staff').
/// Tento mapper poskytuje ikonu a label pro sidebar; [tabIndex] je index v IndexedStack
/// (null = modul zatím nemá obrazovku, zobrazí se placeholder / paywall).
class ModuleIconMapper {
  ModuleIconMapper._();

  static const Map<String, IconData> icons = {
    'dashboard': Icons.dashboard_rounded,
    'staff': Icons.groups_rounded,
    'apartments': Icons.apartment_rounded,
    'reservations': Icons.calendar_month_rounded,
    'tasks': Icons.task_alt_rounded,
    'planning_calendar': Icons.calendar_view_week_rounded,
    'finance': Icons.attach_money_rounded,
    'warehouse': Icons.inventory_2_rounded,
    'smart_lock': Icons.lock_rounded,
    'automation': Icons.smart_toy_rounded,
    'automatic_tasks': Icons.auto_awesome,
  };

  /// i18n klíč pro název položky menu (admin.menu_*).
  static const Map<String, String> labelKeys = {
    'dashboard': 'admin.menu_dashboard',
    'staff': 'admin.menu_staff',
    'apartments': 'admin.menu_apartments',
    'reservations': 'admin.menu_reservations',
    'tasks': 'admin.menu_tasks',
    'planning_calendar': 'admin.menu_planning_calendar',
    'finance': 'admin.menu_finance',
    'warehouse': 'admin.menu_warehouse',
    'smart_lock': 'admin.menu_smart_lock',
    'automation': 'admin.menu_automation',
    'automatic_tasks': 'admin.menu_automatic_tasks',
  };

  /// Index záložky v AdminLayout IndexedStack. Null = modul bez obrazovky (placeholder).
  static const Map<String, int?> tabIndices = {
    'dashboard': 0,
    'staff': 1,
    'apartments': 2,
    'reservations': 3,
    'tasks': 4,
    'planning_calendar': 5,
    'finance': 6,
    'warehouse': null,
    'smart_lock': null,
    'automation': null,
    'automatic_tasks': null,
  };

  static IconData getIcon(String moduleKey) =>
      icons[moduleKey] ?? Icons.extension_rounded;

  static String getLabelKey(String moduleKey) =>
      labelKeys[moduleKey] ?? 'admin.menu_module';

  static int? getTabIndex(String moduleKey) => tabIndices[moduleKey];
}
