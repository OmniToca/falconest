import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:falconest/core/services/supabase_service.dart';
import 'package:falconest/core/utils/app_logger.dart';

/// Klíče JSONB [tenants.integration_settings] pro vlastní SMTP – musí odpovídat Edge funkci
/// `automation-dispatch` (`sendViaSmtpOrFallback`).
const String kTenantIntegrationSmtpHost = 'smtp_host';
const String kTenantIntegrationSmtpPort = 'smtp_port';
const String kTenantIntegrationSmtpUsername = 'smtp_username';
const String kTenantIntegrationSmtpPassword = 'smtp_password';
const String kTenantIntegrationSmtpSenderName = 'smtp_sender_name';

/// Telefonní číslo (E.164) zakoupené přes Twilio self-service – odesílatel SMS v [automation-dispatch].
const String kTenantIntegrationTwilioPhoneNumber = 'twilio_phone_number';

/// Vlastní Twilio účet agentury (REST API) – povinné pro **automatické** WhatsApp zprávy.
const String kTenantIntegrationTwilioAccountSid = 'twilio_account_sid';
const String kTenantIntegrationTwilioAuthToken = 'twilio_auth_token';

/// Načte aktuální [integration_settings] pro daného tenanta.
///
/// PROČ: Oddělený provider od [tenantDetailProvider], aby se nemusel rozšiřovat celý
/// model HQ detailu agentury; RLS stejně vrátí jen řádek aktuální agentury.
final tenantIntegrationSettingsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, tenantId) async {
  if (tenantId.isEmpty) return {};
  try {
    final res = await SupabaseService.client
        .from('tenants')
        .select('integration_settings')
        .eq('id', tenantId)
        .maybeSingle();

    if (res == null) return {};
    final raw = res['integration_settings'];
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  } catch (e, st) {
    AppLogger.error('tenantIntegrationSettingsProvider: načtení integration_settings selhalo', e, st);
    return {};
  }
});

/// Sloučí hodnoty SMTP do existujícího JSONB a uloží jedním UPDATE.
///
/// PROČ: Nejdřív přečteme aktuální [integration_settings] z DB a doplníme/odstraníme jen
/// klíče SMTP. Tím nepřepíšeme budoucí integrace (TTLock, Twilio, …). Prázdný řetězec
/// = klíč z mapy odstraníme (agentura chce smazat uložené heslo / vypnout vlastní SMTP).
Future<void> mergeAndSaveTenantIntegrationSmtpSettings({
  required String tenantId,
  required String smtpHost,
  required String smtpPort,
  required String smtpUsername,
  required String smtpPassword,
  required String smtpSenderName,
}) async {
  final client = SupabaseService.client;

  final existing = await client
      .from('tenants')
      .select('integration_settings')
      .eq('id', tenantId)
      .maybeSingle();

  Map<String, dynamic> current = {};
  if (existing != null) {
    final raw = existing['integration_settings'];
    if (raw is Map<String, dynamic>) {
      current = Map<String, dynamic>.from(raw);
    } else if (raw is Map) {
      current = Map<String, dynamic>.from(raw);
    }
  }

  void putOrRemove(String key, String value) {
    final t = value.trim();
    if (t.isNotEmpty) {
      current[key] = t;
    } else {
      current.remove(key);
    }
  }

  putOrRemove(kTenantIntegrationSmtpHost, smtpHost);
  putOrRemove(kTenantIntegrationSmtpPort, smtpPort);
  putOrRemove(kTenantIntegrationSmtpUsername, smtpUsername);
  putOrRemove(kTenantIntegrationSmtpPassword, smtpPassword);
  putOrRemove(kTenantIntegrationSmtpSenderName, smtpSenderName);

  await client.from('tenants').update({'integration_settings': current}).eq('id', tenantId);
}

/// Sloučí pouze Twilio API údaje (SID / Auth Token) do JSONB – additive k SMTP merge.
///
/// PROČ: Oddělené volání umožní ukládat jen když má tenant aktivní modul [custom_twilio_whatsapp]
/// a nezasahuje do klíčů SMTP.
Future<void> mergeAndSaveTenantTwilioApiSettings({
  required String tenantId,
  required String twilioAccountSid,
  required String twilioAuthToken,
}) async {
  final client = SupabaseService.client;

  final existing = await client
      .from('tenants')
      .select('integration_settings')
      .eq('id', tenantId)
      .maybeSingle();

  Map<String, dynamic> current = {};
  if (existing != null) {
    final raw = existing['integration_settings'];
    if (raw is Map<String, dynamic>) {
      current = Map<String, dynamic>.from(raw);
    } else if (raw is Map) {
      current = Map<String, dynamic>.from(raw);
    }
  }

  void putOrRemove(String key, String value) {
    final t = value.trim();
    if (t.isNotEmpty) {
      current[key] = t;
    } else {
      current.remove(key);
    }
  }

  putOrRemove(kTenantIntegrationTwilioAccountSid, twilioAccountSid);
  putOrRemove(kTenantIntegrationTwilioAuthToken, twilioAuthToken);

  await client.from('tenants').update({'integration_settings': current}).eq('id', tenantId);
}
