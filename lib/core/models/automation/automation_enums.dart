/// ENUMy a parsování pro Automation modul.
///
/// PROČ: V DB jsou hodnoty uloženy jako stringy (Postgres ENUM),
/// takže v aplikaci potřebujeme bezpečně mapovat na Dart enumy.
enum AutomationChannel {
  email,
  sms,
  whatsapp,
  /// Interní FCM připomínka (dispečer), ne host přes Twilio/WhatsApp.
  internalPush,
}

/// Stav položky ve frontě automatizovaných zpráv.
///
/// PROČ: Pomáhá engine i UI mapovat typické workflow stavy.
enum AutomationQueueStatus {
  pending,
  processing,
  sent,
  failed,
  cancelled,
}

extension AutomationChannelParsing on AutomationChannel {
  static AutomationChannel parse(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    switch (v) {
      case 'email':
        return AutomationChannel.email;
      case 'sms':
        return AutomationChannel.sms;
      case 'whatsapp':
        return AutomationChannel.whatsapp;
      case 'internal_push':
        return AutomationChannel.internalPush;
      default:
        // Bezpečný fallback, aby UI/engine nespadlo na nečekané hodnotě.
        return AutomationChannel.email;
    }
  }

  String toDb() {
    return switch (this) {
      AutomationChannel.email => 'email',
      AutomationChannel.sms => 'sms',
      AutomationChannel.whatsapp => 'whatsapp',
      AutomationChannel.internalPush => 'internal_push',
    };
  }
}

extension AutomationQueueStatusParsing on AutomationQueueStatus {
  static AutomationQueueStatus parse(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    switch (v) {
      case 'pending':
        return AutomationQueueStatus.pending;
      case 'processing':
        return AutomationQueueStatus.processing;
      case 'sent':
        return AutomationQueueStatus.sent;
      case 'failed':
        return AutomationQueueStatus.failed;
      case 'cancelled':
        return AutomationQueueStatus.cancelled;
      default:
        // Bezpečný fallback.
        return AutomationQueueStatus.pending;
    }
  }

  String toDb() {
    return switch (this) {
      AutomationQueueStatus.pending => 'pending',
      AutomationQueueStatus.processing => 'processing',
      AutomationQueueStatus.sent => 'sent',
      AutomationQueueStatus.failed => 'failed',
      AutomationQueueStatus.cancelled => 'cancelled',
    };
  }
}

