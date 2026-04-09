/// Jedna „řádka“ matice: Web / Push / E-mail pro daný typ události.
class NotificationChannels {
  const NotificationChannels({
    this.web = true,
    this.push = true,
    this.email = true,
  });

  final bool web;
  final bool push;
  final bool email;

  NotificationChannels copyWith({bool? web, bool? push, bool? email}) {
    return NotificationChannels(
      web: web ?? this.web,
      push: push ?? this.push,
      email: email ?? this.email,
    );
  }

  static bool _readBool(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return true;
    return v == true || v == 1;
  }

  /// [prefix] např. `daily_summary` → čte `daily_summary_web`, …
  factory NotificationChannels.fromJsonPrefix(
    Map<String, dynamic> json,
    String prefix,
  ) {
    return NotificationChannels(
      web: _readBool(json, '${prefix}_web'),
      push: _readBool(json, '${prefix}_push'),
      email: _readBool(json, '${prefix}_email'),
    );
  }

  void addToMap(Map<String, dynamic> map, String prefix) {
    map['${prefix}_web'] = web;
    map['${prefix}_push'] = push;
    map['${prefix}_email'] = email;
  }
}

/// Model preferencí notifikací z tabulky [notification_preferences].
///
/// Pro každý typ události lze zvlášť zapnout kanály Web, Push, E-mail.
class NotificationPreferencesModel {
  const NotificationPreferencesModel({
    required this.profileId,
    required this.tenantId,
    this.dailySummary = const NotificationChannels(),
    this.upcomingTask = const NotificationChannels(),
    this.newTaskAssigned = const NotificationChannels(),
    this.templateReminders = const NotificationChannels(),
  });

  final String profileId;
  final String tenantId;

  final NotificationChannels dailySummary;
  final NotificationChannels upcomingTask;
  final NotificationChannels newTaskAssigned;
  final NotificationChannels templateReminders;

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      profileId: json['profile_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      dailySummary: NotificationChannels.fromJsonPrefix(json, 'daily_summary'),
      upcomingTask: NotificationChannels.fromJsonPrefix(json, 'upcoming_task'),
      newTaskAssigned:
          NotificationChannels.fromJsonPrefix(json, 'new_task_assigned'),
      templateReminders:
          NotificationChannels.fromJsonPrefix(json, 'template_reminders'),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'profile_id': profileId,
      'tenant_id': tenantId,
    };
    dailySummary.addToMap(map, 'daily_summary');
    upcomingTask.addToMap(map, 'upcoming_task');
    newTaskAssigned.addToMap(map, 'new_task_assigned');
    templateReminders.addToMap(map, 'template_reminders');
    return map;
  }

  NotificationPreferencesModel copyWith({
    NotificationChannels? dailySummary,
    NotificationChannels? upcomingTask,
    NotificationChannels? newTaskAssigned,
    NotificationChannels? templateReminders,
  }) {
    return NotificationPreferencesModel(
      profileId: profileId,
      tenantId: tenantId,
      dailySummary: dailySummary ?? this.dailySummary,
      upcomingTask: upcomingTask ?? this.upcomingTask,
      newTaskAssigned: newTaskAssigned ?? this.newTaskAssigned,
      templateReminders: templateReminders ?? this.templateReminders,
    );
  }
}

/// Typ řádku v matici oznámení (shoduje se s předponou sloupců v DB).
enum NotificationEventKind {
  dailySummary,
  upcomingTask,
  newTaskAssigned,
  templateReminders,
}

enum NotificationDeliveryChannel {
  web,
  push,
  email,
}

extension NotificationPreferencesModelChannelPatch on NotificationPreferencesModel {
  NotificationPreferencesModel setChannel(
    NotificationEventKind event,
    NotificationDeliveryChannel ch,
    bool value,
  ) {
    NotificationChannels patch(NotificationChannels c) {
      switch (ch) {
        case NotificationDeliveryChannel.web:
          return c.copyWith(web: value);
        case NotificationDeliveryChannel.push:
          return c.copyWith(push: value);
        case NotificationDeliveryChannel.email:
          return c.copyWith(email: value);
      }
    }

    switch (event) {
      case NotificationEventKind.dailySummary:
        return copyWith(dailySummary: patch(dailySummary));
      case NotificationEventKind.upcomingTask:
        return copyWith(upcomingTask: patch(upcomingTask));
      case NotificationEventKind.newTaskAssigned:
        return copyWith(newTaskAssigned: patch(newTaskAssigned));
      case NotificationEventKind.templateReminders:
        return copyWith(templateReminders: patch(templateReminders));
    }
  }

  NotificationChannels channelsFor(NotificationEventKind event) {
    switch (event) {
      case NotificationEventKind.dailySummary:
        return dailySummary;
      case NotificationEventKind.upcomingTask:
        return upcomingTask;
      case NotificationEventKind.newTaskAssigned:
        return newTaskAssigned;
      case NotificationEventKind.templateReminders:
        return templateReminders;
    }
  }
}
