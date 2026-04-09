import 'package:falconest/core/services/supabase_service.dart';

/// Volání Edge funkce [twilio-provision-number] – nákup Twilio čísla pro aktuální agenturu.
///
/// PROČ: Logika nákupu a merge JSONB je na serveru (Twilio tajemství, autorizace JWT);
/// klient jen posílá `countryCode` a obnoví [tenantIntegrationSettingsProvider].
class TwilioProvisionService {
  TwilioProvisionService._();

  /// Zakoupí první dostupné číslo v dané zemi a vrátí E.164 z odpovědi API.
  ///
  /// PROČ: Explicitní Bearer token – stejný vzor jako [AutomationQueueRepository.invokeAutomationDispatch],
  /// aby gateway Edge funkce nepřijala zastaralý JWT (zejména Flutter Web).
  static Future<String> provisionPhoneNumber({required String countryCode}) async {
    final client = SupabaseService.client;
    final session = client.auth.currentSession;
    if (session == null) {
      throw Exception('TWILIO_PROVISION_NO_SESSION');
    }

    final res = await client.functions.invoke(
      'twilio-provision-number',
      body: {'countryCode': countryCode.trim().toUpperCase()},
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
      },
    );

    final data = res.data;
    if (res.status != 200) {
      final err = _extractError(data);
      throw Exception(err ?? 'HTTP ${res.status}');
    }

    if (data is Map<String, dynamic>) {
      final phone = data['twilio_phone_number'] as String?;
      if (phone != null && phone.trim().isNotEmpty) {
        return phone.trim();
      }
      final err = data['error'] as String?;
      if (err != null && err.isNotEmpty) {
        throw Exception(err);
      }
    }

    throw Exception('TWILIO_PROVISION_INVALID_RESPONSE');
  }

  static String? _extractError(dynamic data) {
    if (data is Map<String, dynamic>) {
      final e = data['error'];
      if (e is String && e.isNotEmpty) return e;
    }
    return null;
  }
}
