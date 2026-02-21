/// Model kategorie úkolu z globální tabulky [task_categories].
/// Platformový číselník – barvy a ikony pro typy úkolů (Kanban, Kalendář, legenda).
class TaskCategoryModel {
  const TaskCategoryModel({
    required this.code,
    required this.colorHex,
    this.iconName,
    this.orderIndex = 0,
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
    return TaskCategoryModel(
      id: json['id'] as String?,
      code: (json['code'] as String?)?.trim().toLowerCase() ?? '',
      colorHex: (json['color_hex'] as String?)?.trim() ?? '#E0E0E0',
      iconName: () {
        final s = (json['icon_name'] as String?)?.trim();
        return (s != null && s.isNotEmpty) ? s : null;
      }(),
      orderIndex: order,
    );
  }
}
