import 'package:flutter/material.dart';

import 'package:falconest/features/admin/models/task_category_model.dart';

/// Jedna položka legendy úkolů – i18n klíč, barva a volitelná ikona.
class TaskLegendItem {
  const TaskLegendItem({
    required this.labelKey,
    required this.color,
    this.icon,
  });

  final String labelKey;
  final Color color;
  final IconData? icon;
}

/// Centrální třída pro vizuální identitu úkolů (barvy a ikony) napříč aplikací.
/// Podporuje dynamická data z DB (task_categories) i statický fallback při prázdné DB.
class TaskVisuals {
  /// Mapování názvu ikony z DB (icon_name) na Flutter IconData.
  /// IconData nelze instancovat ze stringu, proto používáme tento slovník.
  /// Přidej nové položky při rozšíření Material Icons v task_categories.
  static const Map<String, IconData> _iconNameToIconData = {
    'cleaning_services': Icons.cleaning_services,
    'directions_car': Icons.directions_car,
    'key': Icons.key,
    'key_rounded': Icons.key_rounded,
    'warning_amber_rounded': Icons.warning_amber_rounded,
    'task_alt': Icons.task_alt,
    'build_rounded': Icons.build_rounded,
    'add_circle_outline': Icons.add_circle_outline,
    'add_circle_outline_rounded': Icons.add_circle_outline_rounded,
  };

  /// Převod HEX stringu na Color. Podporuje #RRGGBB, #AARRGGBB, RRGGBB.
  /// Při chybě vrací šedou.
  static Color _parseHexColor(String hex) {
    if (hex.isEmpty) return Colors.grey.shade400;
    var h = hex.trim().replaceFirst('#', '');
    if (h.length == 6) {
      final parsed = int.tryParse(h, radix: 16);
      if (parsed != null) return Color(0xFF000000 | parsed);
    } else if (h.length == 8) {
      final parsed = int.tryParse(h, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return Colors.grey.shade400;
  }

  /// Veřejná varianta – vrací kategorii pro taskType (pro UI, např. label v kartě).
  static TaskCategoryModel? resolveCategory(String? taskType, Map<String, TaskCategoryModel>? categoriesByCode) {
    if (categoriesByCode == null || categoriesByCode.isEmpty) return null;
    return _resolveCategory(taskType, categoriesByCode);
  }

  /// Vrátí TaskCategory pro daný taskType – exact match nebo contains (delší kódy mají prioritu).
  static TaskCategoryModel? _resolveCategory(
    String? taskType,
    Map<String, TaskCategoryModel> categoriesByCode,
  ) {
    if (taskType == null || categoriesByCode.isEmpty) return null;
    final t = taskType.toLowerCase().trim();
    // 1) Exact match
    final exact = categoriesByCode[t];
    if (exact != null) return exact;
    // 2) Contains – seřadíme kódy od nejdelšího, první shoda vyhrává
    final sortedCodes = categoriesByCode.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final code in sortedCodes) {
      if (t.contains(code)) return categoriesByCode[code]!;
    }
    return null;
  }

  /// Vrací ikonu z názvu v DB – přes mapu, fallback Icons.task_alt.
  static IconData _iconFromName(String? iconName) {
    if (iconName == null || iconName.isEmpty) return Icons.task_alt;
    final key = iconName.toLowerCase().trim().replaceAll('-', '_');
    return _iconNameToIconData[key] ?? Icons.task_alt;
  }

  /// Dynamická varianta: vrací barvu z DB, při nenalezení fallback na statickou.
  static Color getBackgroundColor(
    String? taskType, {
    Map<String, TaskCategoryModel>? categoriesByCode,
  }) {
    final cat = categoriesByCode != null ? _resolveCategory(taskType, categoriesByCode) : null;
    if (cat != null) return _parseHexColor(cat.colorHex);
    return getBackgroundColorStatic(taskType);
  }

  /// Statický fallback – používá se, když DB nemá kategorie nebo match selže.
  static Color getBackgroundColorStatic(String? taskType) {
    if (taskType == null) return Colors.grey.shade100;
    final t = taskType.toLowerCase();
    if (t.contains('cleaning') || t.contains('úklid')) return Colors.purple.shade50;
    if (t.contains('transfer') || t.contains('příjezd') || t.contains('odjezd')) return Colors.blue.shade50;
    if (t.contains('check_in') || t.contains('check-in') || t.contains('check_out') || t.contains('check-out')) return Colors.orange.shade50;
    if (t.contains('issue') || t.contains('material') || t.contains('materiál') || t.contains('závada') || t.contains('maintenance')) return Colors.red.shade50;
    return Colors.grey.shade100;
  }

  /// Dynamická varianta: vrací border barvu z DB – color_hex ztmavený pro kontrast.
  /// Ztmavení: Color.lerp(barva, black, 0.2) pro lepší viditelnost ohraničení.
  static Color getBorderColor(
    String? taskType, {
    Map<String, TaskCategoryModel>? categoriesByCode,
  }) {
    final cat = categoriesByCode != null ? _resolveCategory(taskType, categoriesByCode) : null;
    if (cat != null) {
      final base = _parseHexColor(cat.colorHex);
      return Color.lerp(base, Colors.black, 0.2) ?? base;
    }
    return getBorderColorStatic(taskType);
  }

  /// Statický fallback pro border barvu.
  static Color getBorderColorStatic(String? taskType) {
    if (taskType == null) return Colors.grey.shade400;
    final t = taskType.toLowerCase();
    if (t.contains('cleaning') || t.contains('úklid')) return Colors.purple.shade300;
    if (t.contains('transfer') || t.contains('příjezd') || t.contains('odjezd')) return Colors.blue.shade300;
    if (t.contains('check_in') || t.contains('check-in') || t.contains('check_out') || t.contains('check-out')) return Colors.orange.shade300;
    if (t.contains('issue') || t.contains('material') || t.contains('materiál') || t.contains('závada') || t.contains('maintenance')) return Colors.red.shade300;
    return Colors.grey.shade400;
  }

  /// Dynamická varianta: vrací ikonu z DB (icon_name → IconData), fallback na statickou.
  static IconData getIcon(
    String? taskType, {
    Map<String, TaskCategoryModel>? categoriesByCode,
  }) {
    final cat = categoriesByCode != null ? _resolveCategory(taskType, categoriesByCode) : null;
    if (cat?.iconName != null) return _iconFromName(cat!.iconName);
    return getIconStatic(taskType);
  }

  /// Statický fallback pro ikonu.
  static IconData getIconStatic(String? taskType) {
    if (taskType == null) return Icons.task_alt;
    final t = taskType.toLowerCase();
    if (t.contains('cleaning') || t.contains('úklid')) return Icons.cleaning_services;
    if (t.contains('transfer') || t.contains('příjezd') || t.contains('odjezd') || t.contains('driver')) return Icons.directions_car;
    if (t.contains('check_in') || t.contains('check-in') || t.contains('check_out') || t.contains('check-out')) return Icons.key;
    if (t.contains('issue') || t.contains('material') || t.contains('materiál') || t.contains('závada') || t.contains('maintenance')) return Icons.warning_amber_rounded;
    return Icons.task_alt;
  }

  /// Statická legenda (fallback při prázdné DB).
  static List<TaskLegendItem> getLegendItems() {
    return [
      TaskLegendItem(labelKey: 'planning_calendar.legend_unassigned', color: Colors.red),
      TaskLegendItem(labelKey: 'planning_calendar.legend_conflict', color: Colors.orange),
      TaskLegendItem(labelKey: 'admin.task_type_cleaning', color: Colors.purple.shade300, icon: Icons.cleaning_services),
      TaskLegendItem(labelKey: 'admin.task_type_transfer_in', color: Colors.blue.shade300, icon: Icons.directions_car),
      TaskLegendItem(labelKey: 'admin.task_type_check_in', color: Colors.orange.shade300, icon: Icons.key),
      TaskLegendItem(labelKey: 'admin.task_type_issue', color: Colors.red.shade300, icon: Icons.warning_amber_rounded),
    ];
  }

  /// Dynamická legenda – kritické stavy + položky z categoriesByCode.
  /// Kategorie se řadí podle order_index. LabelKey se mapuje z code (admin.task_type_{code}).
  static List<TaskLegendItem> getLegendItemsFromCategories(Map<String, TaskCategoryModel> categoriesByCode) {
    final items = <TaskLegendItem>[
      TaskLegendItem(labelKey: 'planning_calendar.legend_unassigned', color: Colors.red),
      TaskLegendItem(labelKey: 'planning_calendar.legend_conflict', color: Colors.orange),
    ];
    final sorted = categoriesByCode.values.toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    for (final c in sorted) {
      items.add(TaskLegendItem(
        labelKey: 'admin.task_type_${c.code}',
        color: _parseHexColor(c.colorHex),
        icon: _iconFromName(c.iconName),
      ));
    }
    // Pokud DB vrací prázdné, doplníme statické typy
    if (sorted.isEmpty) {
      items.addAll(getLegendItems().where((i) => i.labelKey.startsWith('admin.task_type_')));
    }
    return items;
  }
}
