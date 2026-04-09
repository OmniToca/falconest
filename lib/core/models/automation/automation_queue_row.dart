import 'dart:convert';

import 'package:falconest/core/models/automation/automation_enums.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// DTO / row model pro tabulku `automation_message_queue`.
///
/// PROČ: Uchovává položky ve frontě automatizovaných odeslání: kdy, jaký rule/template
/// a jaký konkrétní entity_id je cílem (reservation/task), případně ad-hoc bez pravidla.
class AutomationQueueRow {
  const AutomationQueueRow({
    required this.id,
    required this.tenantId,
    this.ruleId,
    required this.entityId,
    required this.entityType,
    required this.scheduledFor,
    this.status = AutomationQueueStatus.pending,
    required this.channel,
    this.recipientContact,
    this.editablePayload = const {},
    this.attemptCount = 0,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;

  /// PROČ: U ad-hoc zpráv z UI může být NULL (žádné `automation_rules`).
  final String? ruleId;

  /// UUID rezervace nebo úkolu (podle `entityType`); u `adhoc` sentinel viz konstanta níže.
  final String entityId;

  /// 'reservation' | 'task' | 'adhoc'.
  final String entityType;

  /// PROČ: Jednotný placeholder pro `entity_id` u ručních zpráv (DB vyžaduje NOT NULL).
  static const String kAdhocEntitySentinel =
      '00000000-0000-0000-0000-000000000001';

  final DateTime scheduledFor;
  final AutomationQueueStatus status;
  final AutomationChannel channel;

  final String? recipientContact;

  /// JSON payload pro UI úpravu.
  final Map<String, dynamic> editablePayload;

  final int attemptCount;
  final String? lastError;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory AutomationQueueRow.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic raw) {
      if (raw == null) return DateTime.now().toUtc();
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    Map<String, dynamic> parsePayload(dynamic raw) {
      if (raw == null) return const {};
      if (raw is Map) return Map<String, dynamic>.from(raw);
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (e, st) {
          AppLogger.error('AutomationQueueRow: parsování editablePayload JSON řetězce selhalo', e, st);
        }
      }
      return const {};
    }

    int parseInt(dynamic raw, {int fallback = 0}) {
      if (raw == null) return fallback;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString()) ?? fallback;
    }

    final rawRule = json['rule_id'];
    final String? ruleParsed = rawRule == null
        ? null
        : (rawRule as String?)?.trim();

    return AutomationQueueRow(
      id: (json['id'] as String?)?.trim() ?? '',
      tenantId: (json['tenant_id'] as String?)?.trim() ?? '',
      ruleId: (ruleParsed != null && ruleParsed.isEmpty) ? null : ruleParsed,
      entityId: (json['entity_id'] as String?)?.trim() ?? '',
      entityType: (json['entity_type'] as String?)?.trim() ?? 'reservation',
      scheduledFor: parseDateTime(json['scheduled_for']),
      status: AutomationQueueStatusParsing.parse(json['status'] as String?),
      channel: AutomationChannelParsing.parse(json['channel'] as String?),
      recipientContact: (json['recipient_contact'] as String?)?.trim().isEmpty == true ? null : (json['recipient_contact'] as String?)?.trim(),
      editablePayload: parsePayload(json['editable_payload']),
      attemptCount: parseInt(json['attempt_count'], fallback: 0),
      lastError: (json['last_error'] as String?)?.trim().isEmpty == true ? null : (json['last_error'] as String?)?.trim(),
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'rule_id': ruleId,
      'entity_id': entityId,
      'entity_type': entityType,
      'scheduled_for': scheduledFor.toUtc().toIso8601String(),
      'status': status.toDb(),
      'channel': channel.toDb(),
      'recipient_contact': recipientContact,
      'editable_payload': editablePayload,
      'attempt_count': attemptCount,
      'last_error': lastError,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  AutomationQueueRow copyWith({
    String? id,
    String? tenantId,
    String? ruleId,
    String? entityId,
    String? entityType,
    DateTime? scheduledFor,
    AutomationQueueStatus? status,
    AutomationChannel? channel,
    String? recipientContact,
    Map<String, dynamic>? editablePayload,
    int? attemptCount,
    String? lastError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AutomationQueueRow(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      ruleId: ruleId ?? this.ruleId,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      status: status ?? this.status,
      channel: channel ?? this.channel,
      recipientContact: recipientContact ?? this.recipientContact,
      editablePayload: editablePayload ?? this.editablePayload,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

