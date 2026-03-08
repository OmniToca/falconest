import 'package:falconest/core/database/models/sync_status.dart';

/// DTO pro šablonu zprávy (tenant_message_templates) – používán Worker UI.
///
/// Isar odstraněn – DriftMessageTemplateRepository mapuje db.MessageTemplate na tento model.
/// Řidiči používají šablony v terénu bez připojení (offline-first).
class MessageTemplateLocal {
  MessageTemplateLocal();

  /// UUID záznamu v Supabase.
  String? supabaseId;

  /// ID tenanta – multi-tenant izolace.
  late String tenantId;

  /// Systémový identifikátor šablony (např. transfer_48h, at_airport).
  late String key;

  /// Lidský název pro UI (např. „48h před transferem“).
  late String name;

  /// Text s placeholdery: {guest_name}, {flight_number}, {address}, …
  late String body;

  /// Kanál odeslání: whatsapp_link, sms, email.
  String? channel;

  /// i18n: NULL = výchozí, cs/en/es – verze pro jazyky hostů.
  String? languageCode;

  /// Volitelně: transfer, check_in, check_out – filtrování v UI řidiče.
  String? triggerContext;

  /// Pořadí v UI (0 = první).
  int orderIndex = 0;

  /// Stav synchronizace (u šablon vždy synced – Worker jen čte).
  late SyncStatus syncStatus;

  /// Kdy byl záznam naposledy synchronizován z Supabase.
  DateTime? lastSyncedAt;
}
