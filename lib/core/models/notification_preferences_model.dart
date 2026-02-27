/// Model preferencí notifikací z tabulky [notification_preferences].
///
/// Jeden řádek na profil – nastavení ranních souhrnů, upozornění před úkolem
/// a notifikací při přiřazení nového úkolu. Default true = všechny typy povoleny.
class NotificationPreferencesModel {
  const NotificationPreferencesModel({
    required this.profileId,
    required this.tenantId,
    this.dailySummaryEnabled = true,
    this.upcomingTaskEnabled = true,
    this.newTaskAssignedEnabled = true,
  });

  final String profileId;
  final String tenantId;
  /// Ranní souhrn úkolů na den.
  final bool dailySummaryEnabled;
  /// Upozornění před plánovaným úkolem.
  final bool upcomingTaskEnabled;
  /// Notifikace při přiřazení nového úkolu.
  final bool newTaskAssignedEnabled;

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    final rawDaily = json['daily_summary_enabled'];
    final dailySummaryEnabled = rawDaily == null ? true : (rawDaily == true || rawDaily == 1);

    final rawUpcoming = json['upcoming_task_enabled'];
    final upcomingTaskEnabled = rawUpcoming == null ? true : (rawUpcoming == true || rawUpcoming == 1);

    final rawNewTask = json['new_task_assigned_enabled'];
    final newTaskAssignedEnabled = rawNewTask == null ? true : (rawNewTask == true || rawNewTask == 1);

    return NotificationPreferencesModel(
      profileId: json['profile_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      dailySummaryEnabled: dailySummaryEnabled,
      upcomingTaskEnabled: upcomingTaskEnabled,
      newTaskAssignedEnabled: newTaskAssignedEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profile_id': profileId,
      'tenant_id': tenantId,
      'daily_summary_enabled': dailySummaryEnabled,
      'upcoming_task_enabled': upcomingTaskEnabled,
      'new_task_assigned_enabled': newTaskAssignedEnabled,
    };
  }
}

