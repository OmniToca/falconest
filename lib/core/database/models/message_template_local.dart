import 'package:falconest/core/database/models/sync_status.dart';
import 'package:falconest/features/communication/models/message_template_row.dart';

/// DTO pro šablonu zprávy (tenant_message_templates) – používán Worker UI.
///
/// PROČ: Offline-first – Drift ukládá synchronizovaná data; texty jsou v [translationsJson]
/// (stejný význam jako Supabase jsonb). Kanál a předmět e-mailu držíme paralelně se serverem.
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

  /// Kanál odeslání: whatsapp, sms, email.
  String? channel;

  /// Předmět pro e-mail šablony (u sms/whatsapp null).
  String? emailSubject;

  /// JSON překlady šablony (stejný formát jako Supabase `translations` jsonb).
  String? translationsJson;

  /// Volitelně: transfer, check_in, check_out – filtrování v UI řidiče.
  String? triggerContext;

  /// Pořadí v UI (0 = první).
  int orderIndex = 0;

  /// Stav synchronizace (u šablon vždy synced – Worker jen čte).
  late SyncStatus syncStatus;

  /// Kdy byl záznam naposledy synchronizován z Supabase.
  DateTime? lastSyncedAt;

  /// Text pro hosta dle jazyka – čte pouze z [translationsJson], žádný legacy sloupec.
  String resolvedBodyForGuest(String guestLanguageLower) {
    return MessageTemplateTranslations.parseFromStorage(translationsJson)
        .resolvedBodyForGuest(guestLanguageLower);
  }
}
