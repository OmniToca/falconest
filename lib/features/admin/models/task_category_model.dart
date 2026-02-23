/// Model kategorie úkolu z globální tabulky [task_categories].
/// Platformový číselník – barvy, ikony a priorita plánování pro typy úkolů (Kanban, Kalendář, Smart Planner).
class TaskCategoryModel {
  const TaskCategoryModel({
    required this.code,
    required this.colorHex,
    this.iconName,
    this.orderIndex = 0,
    this.planningPriority = 99,
    this.id,
  });

  final String? id;
  /// Systémový klíč pro matchování s task_type – např. 'cleaning', 'transfer_in', 'check_in'.
  final String code;
  /// HEX barva (s # nebo bez) – např. '#FFF3E0'.
  final String colorHex;
  /// Název ikony Material Icons – např. 'directions_car', 'key'.
  final String? iconName;
  /// Pořadí v legendě a dropdownu.
  final int orderIndex;
  /// Priorita plánování v generátoru úkolů – nižší číslo = dřívější přiřazení.
  /// Svaté úkoly (check_in, check_out, transfer_in, transfer_out) = 1; cleaning = 10; maintenance = 20; extra = 30.
  final int planningPriority;

  factory TaskCategoryModel.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['order_index'];
    int order = 0;
    if (rawOrder != null) {
      if (rawOrder is int) {
        order = rawOrder;
      } else if (rawOrder is num) {
        order = rawOrder.toInt();
      }
    }
    final rawPriority = json['planning_priority'];
    int priority = 99;
    if (rawPriority != null) {
      if (rawPriority is int) {
        priority = rawPriority;
      } else if (rawPriority is num) {
        priority = rawPriority.toInt();
      }
    }
    return TaskCategoryModel(
      id: json['id'] as String?,
      code: (json['code'] as String?)?.trim().toLowerCase() ?? '',
      colorHex: (json['color_hex'] as String?)?.trim() ?? '#E0E0E0',
      iconName: () {
        final s = (json['icon_name'] as String?)?.trim();
        return (s != null && s.isNotEmpty) ? s : null;
      }(),
      orderIndex: order,
      planningPriority: priority,
    );
  }

  /// Mapuje JSON klíče (snake_case) na Dart property – pro konzistenci s fromJson.
  factory TaskCategoryModel.fromMap(Map<String, dynamic> map) =>
      TaskCategoryModel.fromJson(map);
}
