import 'package:falconest/core/models/automation/automation_enums.dart';

/// DTO / row model pro tabulku `automation_rules`.
///
/// PROČ: Uchovává konfiguraci pravidel (trigger_event, offset, kanál a template)
/// pro konkrétní tenant (multi-tenant přes `tenant_id`).
class AutomationRuleRow {
  const AutomationRuleRow({
    required this.id,
    required this.tenantId,
    required this.name,
    this.isActive = true,
    required this.triggerEvent,
    required this.offsetMinutes,
    required this.channel,
    required this.templateId,
    required this.targetEntity,
    this.staffProfileId,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  /// UUID v DB.
  final String id;
  /// UUID tenanta (multi-tenant izolace).
  final String tenantId;

  final String name;
  final bool isActive;

  /// Textový trigger události (např. `reservation_check_in`).
  final String triggerEvent;

  /// Offset v minutách oproti triggeru: záporné = předem, kladné = potom.
  final int offsetMinutes;

  final AutomationChannel channel;

  /// FK na `tenant_message_templates.id`.
  final String templateId;

  /// Cíl odesílání: `guest`, `staff` apod.
  final String targetEntity;

  /// PROČ: Pro [AutomationChannel.internalPush] – UUID profilu dispečera (FCM), viz migrace `staff_profile_id`.
  final String? staffProfileId;

  /// Postgres `time` (např. `22:00:00`); reprezentujeme jako string pro jednoduchý transport bez Flutter dependency.
  final String? quietHoursStart;
  /// Postgres `time` (např. `06:00:00`); reprezentujeme jako string.
  final String? quietHoursEnd;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory AutomationRuleRow.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic raw) {
      if (raw == null) return DateTime.now().toUtc();
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    return AutomationRuleRow(
      id: (json['id'] as String?)?.trim() ?? '',
      tenantId: (json['tenant_id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      isActive: json['is_active'] == null
          ? true
          : (json['is_active'] is bool ? json['is_active'] as bool : (json['is_active'].toString() == 'true')),
      triggerEvent: (json['trigger_event'] as String?)?.trim() ?? '',
      offsetMinutes: json['offset_minutes'] == null
          ? 0
          : (json['offset_minutes'] is int ? json['offset_minutes'] as int : int.tryParse(json['offset_minutes'].toString()) ?? 0),
      channel: AutomationChannelParsing.parse(json['channel'] as String?),
      templateId: (json['template_id'] as String?)?.trim() ?? '',
      targetEntity: (json['target_entity'] as String?)?.trim() ?? '',
      staffProfileId: (json['staff_profile_id'] as String?)?.trim().isEmpty == true
          ? null
          : (json['staff_profile_id'] as String?)?.trim(),
      quietHoursStart: (json['quiet_hours_start'] as String?)?.trim().isEmpty == true ? null : (json['quiet_hours_start'] as String?)?.trim(),
      quietHoursEnd: (json['quiet_hours_end'] as String?)?.trim().isEmpty == true ? null : (json['quiet_hours_end'] as String?)?.trim(),
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'is_active': isActive,
      'trigger_event': triggerEvent,
      'offset_minutes': offsetMinutes,
      'channel': channel.toDb(),
      'template_id': templateId,
      'target_entity': targetEntity,
      if (staffProfileId != null && staffProfileId!.trim().isNotEmpty) 'staff_profile_id': staffProfileId!.trim(),
      if (quietHoursStart != null && quietHoursStart!.trim().isNotEmpty) 'quiet_hours_start': quietHoursStart!.trim(),
      if (quietHoursEnd != null && quietHoursEnd!.trim().isNotEmpty) 'quiet_hours_end': quietHoursEnd!.trim(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  AutomationRuleRow copyWith({
    String? id,
    String? tenantId,
    String? name,
    bool? isActive,
    String? triggerEvent,
    int? offsetMinutes,
    AutomationChannel? channel,
    String? templateId,
    String? targetEntity,
    /// PROČ: `null` v [staffProfileId] samo o sobě by přes `??` zachovalo starý profil – explicitní vynulování při změně kanálu.
    bool clearStaffProfileId = false,
    String? staffProfileId,
    String? quietHoursStart,
    String? quietHoursEnd,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AutomationRuleRow(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      triggerEvent: triggerEvent ?? this.triggerEvent,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      channel: channel ?? this.channel,
      templateId: templateId ?? this.templateId,
      targetEntity: targetEntity ?? this.targetEntity,
      staffProfileId: clearStaffProfileId
          ? null
          : (staffProfileId ?? this.staffProfileId),
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

