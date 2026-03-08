/// DTO řádku z tabulky tenant_message_templates.
///
/// Používá se při čtení ze Supabase (admin správa šablon, sync do Isaru).
/// Placeholdery v [body]: {guest_name}, {flight_number}, {address}, {keybox}, …
class MessageTemplateRow {
  const MessageTemplateRow({
    required this.id,
    required this.tenantId,
    required this.key,
    required this.name,
    required this.body,
    this.channel = 'whatsapp_link',
    this.languageCode,
    this.triggerContext,
    this.orderIndex = 0,
    this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String tenantId;
  final String key;
  final String name;
  final String body;
  final String channel;
  final String? languageCode;
  final String? triggerContext;
  final int orderIndex;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  factory MessageTemplateRow.fromJson(Map<String, dynamic> json) {
    final rawChannel = (json['channel'] as String?)?.trim();
    final channel = (rawChannel != null && rawChannel.isNotEmpty)
        ? rawChannel
        : 'whatsapp_link';
    final rawOrder = json['order_index'];
    int orderIndex = 0;
    if (rawOrder != null) {
      if (rawOrder is int) {
        orderIndex = rawOrder;
      } else if (rawOrder is num) {
        orderIndex = rawOrder.toInt();
      }
    }
    return MessageTemplateRow(
      id: (json['id'] as String?) ?? '',
      tenantId: (json['tenant_id']?.toString() ?? '').trim(),
      key: (json['key']?.toString() ?? '').trim(),
      name: (json['name']?.toString() ?? '').trim(),
      body: (json['body']?.toString() ?? '').trim(),
      channel: channel,
      languageCode: (json['language_code'] as String?)?.trim().isEmpty == true
          ? null
          : (json['language_code'] as String?)?.trim(),
      triggerContext:
          (json['trigger_context'] as String?)?.trim().isEmpty == true
              ? null
              : (json['trigger_context'] as String?)?.trim(),
      orderIndex: orderIndex,
      createdAt: _parseDateTime(json['created_at']),
      deletedAt: _parseDateTime(json['deleted_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
