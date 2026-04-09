import 'package:falconest/core/models/automation/automation_enums.dart';

/// DTO / row model pro tabulku `tenant_message_log`.
///
/// PROČ: Uchovává detailní historii zpráv (audit + troubleshooting): outbound
/// (odeslané šablony) i inbound (odpovědi hostů z Twilio inbound webhooku).
class TenantMessageLogRow {
  const TenantMessageLogRow({
    required this.id,
    required this.tenantId,
    this.queueId,
    required this.sentAt,
    required this.channel,
    this.externalApiId,
    required this.status,
    this.unitPrice,
    this.recipientMasked,
    required this.contentSnapshot,
    this.errorDetails,
    required this.createdAt,
    this.direction = 'outbound',
    this.inboundText,
    this.metadata,
  });

  /// Volitelná JSONB metadata z DB (např. `num_segments` u outbound SMS z Twilio).
  final Map<String, dynamic>? metadata;

  final String id;
  final String tenantId;

  /// PROČ: U příchozích zpráv není vazba na frontu automatizací → může být NULL.
  final String? queueId;

  final DateTime sentAt;
  final AutomationChannel channel;

  final String? externalApiId;
  final String status;

  final double? unitPrice;
  final String? recipientMasked;
  final String contentSnapshot;
  final String? errorDetails;

  final DateTime createdAt;

  /// `outbound` | `inbound` (shoda s DB CHECK).
  final String direction;

  /// Text od hosta u příchozích zpráv (`direction == inbound`).
  final String? inboundText;

  factory TenantMessageLogRow.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic raw) {
      if (raw == null) return DateTime.now().toUtc();
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    double? parseDouble(dynamic raw) {
      if (raw == null) return null;
      if (raw is double) return raw;
      if (raw is int) return raw.toDouble();
      if (raw is num) return raw.toDouble();
      final s = raw.toString().trim();
      if (s.isEmpty) return null;
      return double.tryParse(s);
    }

    String? parseNullableTrim(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString().trim();
      return s.isEmpty ? null : s;
    }

    final dirRaw = parseNullableTrim(json['direction']) ?? 'outbound';

    Map<String, dynamic>? meta;
    final rawMeta = json['metadata'];
    if (rawMeta is Map<String, dynamic>) {
      meta = rawMeta;
    } else if (rawMeta is Map) {
      meta = Map<String, dynamic>.from(rawMeta);
    }

    return TenantMessageLogRow(
      id: (json['id'] as String?)?.trim() ?? '',
      tenantId: (json['tenant_id'] as String?)?.trim() ?? '',
      queueId: parseNullableTrim(json['queue_id']),
      sentAt: parseDateTime(json['sent_at']),
      channel: AutomationChannelParsing.parse(json['channel'] as String?),
      externalApiId: parseNullableTrim(json['external_api_id']),
      status: (json['status'] as String?)?.trim() ?? 'failed_at_provider',
      unitPrice: parseDouble(json['unit_price']),
      recipientMasked: parseNullableTrim(json['recipient_masked']),
      contentSnapshot: (json['content_snapshot'] as String?)?.trim() ?? '',
      errorDetails: parseNullableTrim(json['error_details']),
      createdAt: parseDateTime(json['created_at']),
      direction: dirRaw,
      inboundText: parseNullableTrim(json['inbound_text']),
      metadata: meta,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'queue_id': queueId,
      'direction': direction,
      'inbound_text': inboundText,
      'sent_at': sentAt.toUtc().toIso8601String(),
      'channel': channel.toDb(),
      'external_api_id': externalApiId,
      'status': status,
      'unit_price': unitPrice,
      'recipient_masked': recipientMasked,
      'content_snapshot': contentSnapshot,
      'error_details': errorDetails,
      'created_at': createdAt.toUtc().toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  TenantMessageLogRow copyWith({
    String? id,
    String? tenantId,
    String? queueId,
    DateTime? sentAt,
    AutomationChannel? channel,
    String? externalApiId,
    String? status,
    double? unitPrice,
    String? recipientMasked,
    String? contentSnapshot,
    String? errorDetails,
    DateTime? createdAt,
    String? direction,
    String? inboundText,
    Map<String, dynamic>? metadata,
  }) {
    return TenantMessageLogRow(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      queueId: queueId ?? this.queueId,
      sentAt: sentAt ?? this.sentAt,
      channel: channel ?? this.channel,
      externalApiId: externalApiId ?? this.externalApiId,
      status: status ?? this.status,
      unitPrice: unitPrice ?? this.unitPrice,
      recipientMasked: recipientMasked ?? this.recipientMasked,
      contentSnapshot: contentSnapshot ?? this.contentSnapshot,
      errorDetails: errorDetails ?? this.errorDetails,
      createdAt: createdAt ?? this.createdAt,
      direction: direction ?? this.direction,
      inboundText: inboundText ?? this.inboundText,
      metadata: metadata ?? this.metadata,
    );
  }
}

