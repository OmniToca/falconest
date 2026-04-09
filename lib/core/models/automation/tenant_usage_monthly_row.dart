import 'package:falconest/core/models/automation/automation_enums.dart';

/// DTO / row model pro tabulku `tenant_usage_monthly`.
///
/// PROČ: Slouží jako měsíční agregace (per tenant + channel) pro post-paid billing
/// nadspotřeby SMS/WA/E-mail (overage).
class TenantUsageMonthlyRow {
  const TenantUsageMonthlyRow({
    required this.id,
    required this.tenantId,
    required this.billingMonth,
    required this.channel,
    this.sentCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  /// Formát 'YYYY-MM'
  final String billingMonth;
  final AutomationChannel channel;
  final int sentCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory TenantUsageMonthlyRow.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic raw) {
      if (raw == null) return DateTime.now().toUtc();
      if (raw is DateTime) return raw.toUtc();
      if (raw is String) return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
      return DateTime.now().toUtc();
    }

    int parseInt(dynamic raw, {int fallback = 0}) {
      if (raw == null) return fallback;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString()) ?? fallback;
    }

    return TenantUsageMonthlyRow(
      id: (json['id'] as String?)?.trim() ?? '',
      tenantId: (json['tenant_id'] as String?)?.trim() ?? '',
      billingMonth: (json['billing_month'] as String?)?.trim() ?? '',
      channel: AutomationChannelParsing.parse(json['channel'] as String?),
      sentCount: parseInt(json['sent_count'], fallback: 0),
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'billing_month': billingMonth,
      'channel': channel.toDb(),
      'sent_count': sentCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  TenantUsageMonthlyRow copyWith({
    String? id,
    String? tenantId,
    String? billingMonth,
    AutomationChannel? channel,
    int? sentCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TenantUsageMonthlyRow(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      billingMonth: billingMonth ?? this.billingMonth,
      channel: channel ?? this.channel,
      sentCount: sentCount ?? this.sentCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

